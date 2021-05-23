resource "null_resource" "nomad_readiness" {
  triggers = {
    address = var.nomad_addr
  }

  provisioner "local-exec" {
    command = <<EOT
        timeout 300 bash -c 'while [[ "$(curl -s -o /dev/null -w ''%%{http_code}'' ${var.nomad_addr}/v1/status/leader)" != "200" ]]; do sleep 5; done' || false
EOT
  }
}

resource "nomad_job" "prometheus" {
  depends_on = [null_resource.nomad_readiness]
  jobspec = file(
    "${path.module}/templates/prometheus.nomad"
  )
}

resource "nomad_job" "autoscaler" {
  depends_on = [null_resource.nomad_readiness]
  jobspec = templatefile(
    "${path.module}/templates/autoscaler.nomad",
    {
      region      = var.region,
      snapshot_id = var.snapshot_id,
      token       = var.do_token,
      ssh_key     = var.ssh_key,
      vpc_uuid    = var.vpc_uuid
    }
  )
}

resource "nomad_job" "batch" {
  depends_on = [null_resource.nomad_readiness]
  jobspec = file(
    "${path.module}/templates/batch.nomad"
  )
}