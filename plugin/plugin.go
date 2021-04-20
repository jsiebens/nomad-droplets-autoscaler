package plugin

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"strconv"
	"strings"

	"github.com/digitalocean/godo"
	"github.com/hashicorp/go-hclog"
	"github.com/hashicorp/nomad-autoscaler/plugins"
	"github.com/hashicorp/nomad-autoscaler/plugins/base"
	"github.com/hashicorp/nomad-autoscaler/plugins/target"
	"github.com/hashicorp/nomad-autoscaler/sdk"
	"github.com/hashicorp/nomad-autoscaler/sdk/helper/nomad"
	"github.com/hashicorp/nomad-autoscaler/sdk/helper/scaleutils"
	"github.com/mitchellh/go-homedir"
)

const (
	// pluginName is the unique name of the this plugin amongst Target plugins.
	pluginName = "do-droplets"

	configKeyToken      = "token"
	configKeyRegion     = "region"
	configKeySize       = "size"
	configKeyVpcUUID    = "vpc_uuid"
	configKeySnapshotID = "snapshot_id"
	configKeySshKeys    = "ssh_keys"
	configKeyUserData   = "user_data"
	configKeyTags       = "tags"
)

var (
	PluginConfig = &plugins.InternalPluginConfig{
		Factory: func(l hclog.Logger) interface{} { return NewDODropletsPlugin(l) },
	}

	pluginInfo = &base.PluginInfo{
		Name:       pluginName,
		PluginType: sdk.PluginTypeTarget,
	}
)

// Assert that TargetPlugin meets the target.Target interface.
var _ target.Target = (*TargetPlugin)(nil)

// TargetPlugin is the DigitalOcean implementation of the target.Target interface.
type TargetPlugin struct {
	config map[string]string
	logger hclog.Logger

	client *godo.Client

	// clusterUtils provides general cluster scaling utilities for querying the
	// state of nodes pools and performing scaling tasks.
	clusterUtils *scaleutils.ClusterScaleUtils
}

// NewDODropletsPlugin returns the DO Droplets implementation of the target.Target
// interface.
func NewDODropletsPlugin(log hclog.Logger) *TargetPlugin {
	return &TargetPlugin{
		logger: log,
	}
}

// PluginInfo satisfies the PluginInfo function on the base.Base interface.
func (t *TargetPlugin) PluginInfo() (*base.PluginInfo, error) {
	return pluginInfo, nil
}

// SetConfig satisfies the SetConfig function on the base.Base interface.
func (t *TargetPlugin) SetConfig(config map[string]string) error {
	t.config = config

	token, ok := config[configKeyToken]

	if ok {
		contents, err := pathOrContents(token)
		if err != nil {
			return fmt.Errorf("failed to read token: %v", err)
		}
		t.client = godo.NewFromToken(contents)
	} else {
		tokenFromEnv := getEnv("DIGITALOCEAN_TOKEN", "DIGITALOCEAN_ACCESS_TOKEN")
		if len(tokenFromEnv) == 0 {
			return fmt.Errorf("unable to find DigitalOcean token")
		}
		t.client = godo.NewFromToken(tokenFromEnv)
	}

	clusterUtils, err := scaleutils.NewClusterScaleUtils(nomad.ConfigFromNamespacedMap(config), t.logger)
	if err != nil {
		return err
	}

	// Store and set the remote ID callback function.
	t.clusterUtils = clusterUtils
	t.clusterUtils.ClusterNodeIDLookupFunc = doDropletNodeIDMap

	return nil
}

// Scale satisfies the Scale function on the target.Target interface.
func (t *TargetPlugin) Scale(action sdk.ScalingAction, config map[string]string) error {
	// DigitalOcean can't support dry-run like Nomad, so just exit.
	if action.Count == sdk.StrategyActionMetaValueDryRunCount {
		return nil
	}

	template, err := t.createDropletTemplate(config)
	if err != nil {
		return err
	}

	ctx := context.Background()

	total, _, err := t.countDroplets(ctx, template)
	if err != nil {
		return fmt.Errorf("failed to describe DigitalOcedroplets: %v", err)
	}

	num, direction := t.calculateDirection(total, action.Count)

	switch direction {
	case "in":
		err = t.scaleIn(ctx, num, template, config)
	case "out":
		err = t.scaleOut(ctx, num, template, config)
	default:
		t.logger.Info("scaling not required", "tag", template.nodeClass,
			"current_count", total, "strategy_count", action.Count)
		return nil
	}

	// If we received an error while scaling, format this with an outer message
	// so its nice for the operators and then return any error to the caller.
	if err != nil {
		err = fmt.Errorf("failed to perform scaling action: %v", err)
	}
	return err
}

// Status satisfies the Status function on the target.Target interface.
func (t *TargetPlugin) Status(config map[string]string) (*sdk.TargetStatus, error) {
	// Perform our check of the Nomad node pool. If the pool is not ready, we
	// can exit here and avoid calling the Google API as it won't affect the
	// outcome.
	ready, err := t.clusterUtils.IsPoolReady(config)
	if err != nil {
		return nil, fmt.Errorf("failed to run Nomad node readiness check: %v", err)
	}
	if !ready {
		return &sdk.TargetStatus{Ready: ready}, nil
	}

	template, err := t.createDropletTemplate(config)
	if err != nil {
		return nil, err
	}

	ctx := context.Background()

	total, active, err := t.countDroplets(ctx, template)
	if err != nil {
		return nil, fmt.Errorf("failed to describe DigitalOcedroplets: %v", err)
	}

	resp := &sdk.TargetStatus{
		Ready: total == active,
		Count: total,
		Meta:  make(map[string]string),
	}

	return resp, nil
}

func (t *TargetPlugin) createDropletTemplate(config map[string]string) (*dropletTemplate, error) {

	// We cannot scale droplets without knowing the region.
	region, ok := t.getValue(config, configKeyRegion)
	if !ok {
		return nil, fmt.Errorf("required config param %s not found", configKeyRegion)
	}

	// We cannot scale droplets without knowing the size.
	size, ok := t.getValue(config, configKeySize)
	if !ok {
		return nil, fmt.Errorf("required config param %s not found", configKeySize)
	}

	// We cannot scale droplets without knowing the target VPC.
	vpc, ok := t.getValue(config, configKeyVpcUUID)
	if !ok {
		return nil, fmt.Errorf("required config param %s not found", configKeyVpcUUID)
	}

	// We cannot scale droplets without knowing the target node class.
	snapshot, ok := t.getValue(config, configKeySnapshotID)
	if !ok {
		return nil, fmt.Errorf("required config param %s not found", configKeySnapshotID)
	}
	snapshotID, err := strconv.ParseInt(snapshot, 10, 0)
	if err != nil {
		return nil, fmt.Errorf("invalid value for config param %s", configKeySnapshotID)
	}

	sshKeyFingerprint, _ := t.getValue(config, configKeySshKeys)
	tags, _ := t.getValue(config, configKeyTags)
	userData, _ := t.getValue(config, configKeyUserData)

	// We cannot scale droplets without knowing the target node class.
	nodeClass, ok := config[sdk.TargetConfigKeyClass]
	if !ok {
		return nil, fmt.Errorf("required config param %s not found", sdk.TargetConfigKeyClass)
	}

	return &dropletTemplate{
		region:     region,
		size:       size,
		vpc:        vpc,
		snapshotID: int(snapshotID),
		nodeClass:  nodeClass,
		sshKeys:    strings.Split(sshKeyFingerprint, ","),
		userData:   userData,
		tags:       strings.Split(tags, ","),
	}, nil
}

func (t *TargetPlugin) calculateDirection(target, desired int64) (int64, string) {
	if desired < target {
		return target - desired, "in"
	}
	if desired > target {
		return desired - target, "out"
	}
	return 0, ""
}

func (t *TargetPlugin) getValue(config map[string]string, name string) (string, bool) {
	v, ok := config[name]
	if ok {
		return v, true
	}

	v, ok = t.config[name]
	if ok {
		return v, true
	}

	return "", false
}

func pathOrContents(poc string) (string, error) {
	if len(poc) == 0 {
		return poc, nil
	}

	path := poc
	if path[0] == '~' {
		var err error
		path, err = homedir.Expand(path)
		if err != nil {
			return path, err
		}
	}

	if _, err := os.Stat(path); err == nil {
		contents, err := ioutil.ReadFile(path)
		if err != nil {
			return string(contents), err
		}
		return string(contents), nil
	}

	return poc, nil
}

func getEnv(keys ...string) string {
	for _, key := range keys {
		v := os.Getenv(key)
		if len(v) != 0 {
			return v
		}
	}
	return ""
}
