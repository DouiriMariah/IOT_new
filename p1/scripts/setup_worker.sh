#!/usr/bin/env bash
# Inception-of-Things - Part 1 - K3s agent (worker) provisioning.
set -euxo pipefail

IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

# The server node writes its join token to /vagrant/node-token once
# ready; wait for it (Vagrant brings machines up in definition order,
# so this is normally already there, but we stay defensive).
until [ -f /vagrant/node-token ]; do
  sleep 2
done
K3S_TOKEN=$(cat /vagrant/node-token)

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${K3S_TOKEN}" \
  INSTALL_K3S_EXEC="agent \
    --node-ip=${NODE_IP} \
    --flannel-iface=${IFACE}" \
  sh -

echo "K3s agent joined ${SERVER_IP} from ${NODE_IP} (interface ${IFACE})"
