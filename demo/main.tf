terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.8.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "nomad" {
  address = module.infrastructure.nomad_addr
}

# Pre-flight check.
resource "null_resource" "preflight_check" {
  provisioner "local-exec" {
    command = <<EOF
curl --version && \
packer --version && \
nomad --version
EOF
  }
}

module "image" {
  depends_on = [null_resource.preflight_check]
  source     = "./image"
  do_token   = var.do_token
  region     = var.region
  image      = var.image
}

module "infrastructure" {
  depends_on  = [null_resource.preflight_check]
  source      = "./infrastructure"
  do_token    = var.do_token
  snapshot_id = module.image.snapshot_id
  ssh_key     = var.ssh_key
  region      = var.region
  ip_range    = var.ip_range
}

module "jobs" {
  depends_on  = [null_resource.preflight_check]
  source      = "./jobs"
  do_token    = var.do_token
  nomad_addr  = module.infrastructure.nomad_addr
  snapshot_id = module.image.snapshot_id
  region      = var.region
  vpc_uuid    = module.infrastructure.vpc_uuid
  ssh_key     = var.ssh_key
}