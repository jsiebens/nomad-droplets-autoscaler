output "vpc_uuid" {
  value = digitalocean_vpc.hashi.id
}

output "nomad_addr" {
  value = "http://${digitalocean_droplet.hashi-server[0].ipv4_address}:4646"
}

output "consul_addr" {
  value = "http://${digitalocean_droplet.hashi-server[0].ipv4_address}:8500"
}

output "platform_addr" {
  value = digitalocean_droplet.platform[0].ipv4_address
}