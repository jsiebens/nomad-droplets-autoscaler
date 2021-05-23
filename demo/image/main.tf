terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.8.0"
    }
  }
}

locals {
  name = random_pet.name.id
}

resource "random_pet" "name" {}

resource "null_resource" "packer_build" {
  provisioner "local-exec" {
    command = <<EOF
cd ${path.module}/packer && \
  packer build -force \
    -var 'name=hashi-${local.name}' \
    -var 'region=${var.region}' \
    -var 'token=${var.do_token}' \
    do-packer.pkr.hcl
EOF
  }
}

data "digitalocean_image" "hashi" {
  depends_on = [null_resource.packer_build]
  name       = "hashi-${local.name}"
}

output "snapshot_id" {
  value = data.digitalocean_image.hashi.id
}