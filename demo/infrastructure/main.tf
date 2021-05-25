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
  tags      = ["hashi-stack", local.server_tag]
  user_data = templatefile("${path.module}/templates/server.sh", { server_tag = local.server_tag, do_token = var.do_token, nr_of_servers = local.nr_of_servers })
  vpc_uuid  = digitalocean_vpc.hashi.id
  ssh_keys  = [var.ssh_key]
}

resource "digitalocean_droplet" "platform" {
  count     = 1
  image     = var.snapshot_id
  name      = "hashi-platform-0${count.index + 1}"
  region    = var.region
  size      = "s-1vcpu-2gb"
  tags      = ["hashi-stack", "hashi-platform"]
  user_data = templatefile("${path.module}/templates/client.sh", { datacenter = "platform", server_tag = local.server_tag, do_token = var.do_token })
  vpc_uuid  = digitalocean_vpc.hashi.id
  ssh_keys  = [var.ssh_key]
}

module "my_ip_address" {
  source  = "matti/resource/shell"
  command = "curl https://ipinfo.io/ip"
}

resource "digitalocean_firewall" "hashi-stack-internal" {
  name = "hashi-stack"

  tags = ["hashi-stack"]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "4646"
    source_addresses = ["${module.my_ip_address.stdout}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8500"
    source_addresses = ["${module.my_ip_address.stdout}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = ["${module.my_ip_address.stdout}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8081"
    source_addresses = ["${module.my_ip_address.stdout}/32"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = ["${module.my_ip_address.stdout}/32"]
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = ["hashi-stack"]
  }

  inbound_rule {
    protocol    = "udp"
    port_range  = "1-65535"
    source_tags = ["hashi-stack"]
  }

  inbound_rule {
    protocol    = "icmp"
    source_tags = ["hashi-stack"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}