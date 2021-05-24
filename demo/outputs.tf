output "detail" {
  value = <<CONFIGURATION

The Nomad UI can be accessed at ${module.infrastructure.nomad_addr}/ui
The Consul UI can be accessed at ${module.infrastructure.consul_addr}/ui

Grafana dashboard can be accessed at http://${module.infrastructure.platform_addr}:3000/d/CJlc3r_Mk/on-demand-batch-job-demo?orgId=1&refresh=5s
Traefik can be accessed at http://${module.infrastructure.platform_addr}:8081
Prometheus can be accessed at http://${module.infrastructure.platform_addr}:9090

CLI environment variables:
export NOMAD_ADDR=${module.infrastructure.nomad_addr}
CONFIGURATION
}

output "dispatch" {
  value = "nomad job dispatch -address=${module.infrastructure.nomad_addr} batch"
}