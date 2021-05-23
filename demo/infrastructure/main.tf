terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.8.0"
    }
  }
}

locals {
  nr_of_servers = 1
  server_tag    = "hashi-server"
}

resource "digitalocean_vpc" "hashi" {
  name     = "hashistack"
  region   = var.region
  ip_range = var.ip_range
}

resource "digitalocean_droplet" "hashi-server" {
  count     = local.nr_of_servers
  image     = var.snapshot_id
  name      = "hashi-server-0${count.index + 1}"
  region    = var.region
  size      = "s-1vcpu-1gb"
  tags      = [local.server_tag]
  user_data = templatefile("${path.module}/templates/server.sh", { server_tag = local.server_tag, do_token = var.do_token, nr_of_servers = local.nr_of_servers })
  vpc_uuid  = digitalocean_vpc.hashi.id
  ssh_keys  = [var.ssh_key]
}

resource "digitalocean_droplet" "platform" {
  count     = 1
  image     = var.snapshot_id
  name      = "hashi-platform-0${count.index + 1}"
  region    = var.region
  size      = "s-1vcpu-1gb"
  user_data = templatefile("${path.module}/templates/client.sh", { node_class = "platform", server_tag = local.server_tag, do_token = var.do_token })
  vpc_uuid  = digitalocean_vpc.hashi.id
  ssh_keys  = [var.ssh_key]
}

