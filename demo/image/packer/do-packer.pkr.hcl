variable "name" {
}

variable "source_image" {
  default = "ubuntu-20-04-x64"
}

variable "ssh_username" {
  default = "root"
}

variable "region" {
}

variable "token" {
}

source "digitalocean" "hashistack" {
  snapshot_name = "${var.name}"
  image         = "${var.source_image}"
  ssh_username  = "${var.ssh_username}"
  region        = "${var.region}"
  size          = "512mb"
  api_token     = "${var.token}"
}

build {
  sources = [
    "source.digitalocean.hashistack"
  ]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /ops",
      "sudo chmod 777 /ops"
    ]
  }

  provisioner "file" {
    source      = "./scripts"
    destination = "/ops"
  }

  provisioner "shell" {
    script = "./scripts/setup.sh"
  }

}
