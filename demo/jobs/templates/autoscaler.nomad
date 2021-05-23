job "autoscaler" {
  datacenters = ["dc1"]

  constraint {
    attribute = "$${node.class}"
    value     = "platform"
  }

  group "autoscaler" {
    count = 1

    network {
      port "http" {}
    }

    task "autoscaler" {
      driver = "docker"

      artifact {
        source      = "https://github.com/jsiebens/nomad-droplets-autoscaler/releases/download/v0.1.2/do-droplets_linux_amd64.zip"
        destination = "local/plugins/"
      }

      config {
        image   = "hashicorp/nomad-autoscaler:0.3.3"
        command = "nomad-autoscaler"

        args = [
          "agent",
          "-config", "local/config.hcl",
          "-plugin-dir", "local/plugins/"
        ]
        ports   = ["http"]
      }

      template {
        data = <<EOF
http {
  bind_address = "0.0.0.0"
  bind_port    = {{ env "NOMAD_PORT_http" }}
}

policy {
  dir = "local/policies"
}

nomad {
  address = "http://{{ env "attr.unique.network.ip-address" }}:4646"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://{{ range service "prometheus" }}{{ .Address }}:{{ .Port }}{{ end }}"
  }
}

strategy "target-value" {
  driver = "target-value"
}

strategy "pass-through" {
  driver = "pass-through"
}

target "do-droplets" {
  driver = "do-droplets"
  config = {
    token = "${token}"
    ssh_keys = "${ssh_key}"
    vpc_uuid = "${vpc_uuid}"
  }
}
EOF

        destination = "local/config.hcl"
      }

      template {
        data = <<EOF
scaling "batch" {
  enabled = true
  min = 0
  max = 10

  policy {
    cooldown            = "1m"
    evaluation_interval = "10s"

    check "batch_jobs_in_progess" {
      source = "prometheus"
      query  = "sum(nomad_nomad_job_summary_queued{exported_job=~\"batch/.*\"} + nomad_nomad_job_summary_running{exported_job=~\"batch/.*\"}) OR on() vector(0)"

      strategy "pass-through" {}
    }

    target "do-droplets" {
      region = "${region}"
      size = "s-1vcpu-1gb"
      snapshot_id = ${snapshot_id}
      user_data = "local/batch-startup.sh"
      name = "hashi-batch"
      node_class = "batch"
      node_drain_deadline = "1h"
      node_selector_strategy = "empty_ignore_system"
    }
  }
}
EOF

        destination = "local/policies/batch.hcl"
      }

      template {
        destination = "local/batch-startup.sh"
        data = <<EOF
#!/bin/bash
/ops/scripts/client.sh "batch" "hashi-server" "${token}"
EOF
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "5s"
          timeout  = "2s"
        }
      }
    }
  }
}