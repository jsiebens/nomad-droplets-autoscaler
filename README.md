# Nomad DigitalOcean Droplets Autoscaler

The `do-droplets` target plugin allows for the scaling of the Nomad cluster clients via creating and
destroying [DigitalOcean Droplets](https://www.digitalocean.com/products/droplets/).

## Requirements

- nomad autoscaler 0.3.0+
- DigitalOcean account

## Documentation

### Agent Configuration Options

To use the `do-droplets` target plugin, the agent configuration needs to be populated with the appropriate target block.
Currently, Personal Access Token (PAT) is the only method of authenticating with the API. You can manage your tokens at the DigitalOcean Control Panel [Applications Page](https://cloud.digitalocean.com/settings/applications).

```
target "do-droplets" {
  driver = "do-droplets"
  config = {
    token = "local/token"
  }
}
```

- `token` `(string: "")` - a DigitalOcean API token or a path to a file containing a token. Alternatively, this can also be specified using environment variables ordered by precedence:
  - `DIGITALOCEAN_TOKEN`
  - `DIGITALOCEAN_ACCESS_TOKEN`

### Policy Configuration Options

```hcl
check "hashistack-allocated-cpu" {
  # ...
  target "do-droplets" {
    name                = "hashi-worker"
    region              = "nyc1"
    size                = "s-1vcpu-1gb"
    snapshot_id         = 84589509
    user_data           = "local/hashi-worker-user-data.sh"
    tags                = "hashi-stack"
    node_class          = "hashistack"
    node_drain_deadline = "5m"
    node_purge          = "true"
  }
  # ...
}
```

- `name` `(string: <required>)` - A logical name of a Droplet "group". Every managed Droplet will be tagged with this value and its name is this value with a random suffix
- `region` `(string: <required>)` - The region to start in.

- `vpc_uuid` `(string: <required>)` - The ID of the VPC where the Droplet will be located.

- `size` `(string: <required>)` - The unique slug that indentifies the type of Droplet. You can find a list of available slugs on [DigitalOcean API documentation](https://developers.digitalocean.com/documentation/v2/#list-all-sizes).

- `snapshot_id` `(string: <required>)` - The Droplet image ID.

- `user_data` `(string: "")` - A string of the desired User Data for the Droplet or a path to a file containing the User Data

- `ssh_keys` `(string: "")` - A comma-separated list of SSH fingerprints to enable

- `tags` `(string: "")` - A comma-separated list of additional tags to be applied to the Droplets.

- `datacenter` `(string: "")` - The Nomad client [datacenter](https://www.nomadproject.io/docs/configuration#datacenter)
  identifier used to group nodes into a pool of resource. Conflicts with
  `node_class`.

- `node_class` `(string: "")` - The Nomad [client node class](https://www.nomadproject.io/docs/configuration/client#node_class)
  identifier used to group nodes into a pool of resource. Conflicts with
  `datacenter`.

- `node_drain_deadline` `(duration: "15m")` The Nomad [drain deadline](https://www.nomadproject.io/api-docs/nodes#deadline) to use when performing node draining
  actions. **Note that the default value for this setting differs from Nomad's
  default of 1h.**

- `node_drain_ignore_system_jobs` `(bool: "false")` A boolean flag used to
  control if system jobs should be stopped when performing node draining
  actions.

- `node_purge` `(bool: "false")` A boolean flag to determine whether Nomad
  clients should be [purged](https://www.nomadproject.io/api-docs/nodes#purge-node) when performing scale in
  actions.

- `node_selector_strategy` `(string: "least_busy")` The strategy to use when
  selecting nodes for termination. Refer to the [node selector
  strategy](https://www.nomadproject.io/docs/autoscaling/internals/node-selector-strategy) documentation for more information.

- `tailscale_api_key` `(string: "")` The [tailscale api key](https://tailscale.com/kb/1101/api/) for the plugin to use. Enables deleting
  the [tailscale
  device](https://github.com/tailscale/tailscale/blob/main/api.md#device)
  associated with the node when performing scale in. Alternatively, this can
  also be specified using environment variables ordered by precedence:

  - `TAILSCALE_API_KEY`

- `tailscale_tailnet` `(string: "")` The [tailscale tailnet](https://tailscale.com/kb/1101/api/) for the plugin to use.
