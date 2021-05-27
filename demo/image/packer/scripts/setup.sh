#! /bin/bash
set -euo pipefail

echo "Waiting for cloud-init to update /etc/apt/sources.list"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

# Disable interactive apt prompts
export DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

apt-get update
apt-get install -y dnsmasq curl unzip docker.io

mkdir -p /opt/cni/bin
curl -sSL https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz | tar -xvz -C /opt/cni/bin

curl -sL get.hashi-up.dev | sh

hashi-up consul install \
  --version 1.9.5 \
  --local \
  --skip-enable

hashi-up nomad install \
  --version 1.1.0 \
  --local \
  --skip-enable

echo "server=/consul/127.0.0.1#8600" > /etc/dnsmasq.d/10-consul
echo "server=8.8.8.8" > /etc/dnsmasq.d/99-default

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved
rm /etc/resolv.conf

echo 'debconf debconf/frontend select Dialog' | sudo debconf-set-selections