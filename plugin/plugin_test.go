package plugin

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTargetPlugin_calculateDirection(t *testing.T) {
	testCases := []struct {
		inputMigTarget       int64
		inputStrategyDesired int64
		expectedOutputNum    int64
		expectedOutputString string
		name                 string
	}{
		{
			inputMigTarget:       10,
			inputStrategyDesired: 11,
			expectedOutputNum:    1,
			expectedOutputString: "out",
			name:                 "scale out desired",
		},
		{
			inputMigTarget:       10,
			inputStrategyDesired: 9,
			expectedOutputNum:    1,
			expectedOutputString: "in",
			name:                 "scale in desired",
		},
		{
			inputMigTarget:       10,
			inputStrategyDesired: 10,
			expectedOutputNum:    0,
			expectedOutputString: "",
			name:                 "scale not desired",
		},
	}

	tp := TargetPlugin{}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			actualNum, actualString := tp.calculateDirection(tc.inputMigTarget, tc.inputStrategyDesired)
			assert.Equal(t, tc.expectedOutputNum, actualNum, tc.name)
			assert.Equal(t, tc.expectedOutputString, actualString, tc.name)
		})
	}
}

func TestTargetPlugin_createDropletTemplate(t *testing.T) {
	input := map[string]string{
		"region" : "ny1",
		"size" : "s-1vcpu-1gb",
		"vpc_uuid" : "b6ac51f4-dc83-11e8-a3da-3cfdfea9f0d8",
		"snapshot_id" : "123",
		"node_class" : "hashistack",
	}

	plugin := TargetPlugin{}
	dropletTemplate, err := plugin.createDropletTemplate(input)

	assert.Nil(t, err)
	assert.Equal(t, []string{}, dropletTemplate.sshKeys)
	assert.Equal(t, []string{"hashistack"}, dropletTemplate.tags)
}

func TestTargetPlugin_createDropletTemplateWithMultipleTags(t *testing.T) {
	input := map[string]string{
		"region" : "ny1",
		"size" : "s-1vcpu-1gb",
		"vpc_uuid" : "b6ac51f4-dc83-11e8-a3da-3cfdfea9f0d8",
		"snapshot_id" : "123",
		"tags" : "tag1,tag2",
		"node_class" : "hashistack",
	}

	plugin := TargetPlugin{}
	dropletTemplate, err := plugin.createDropletTemplate(input)

	assert.Nil(t, err)
	assert.Equal(t, []string{"hashistack", "tag1", "tag2"}, dropletTemplate.tags)
}