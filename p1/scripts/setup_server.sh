#!/usr/bin/env bash
# Inception-of-Things - Part 1 - K3s server (control-plane) provisioning.
set -euxo pipefail

# Modern Debian/Vagrant boxes use predictable interface names
# (enp0sX, ...) instead of eth0/eth1, so we detect the interface that
# actually carries our static IP instead of hard-coding a name.
IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server \
    --node-ip=${NODE_IP} \
    --advertise-address=${NODE_IP} \
    --flannel-iface=${IFACE} \
    --write-kubeconfig-mode=644" \
  sh -

# Wait until the API server actually answers before going further.
until k3s kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

# Publish the join token through the synced folder (/vagrant is shared
# by both VMs, each mounting this same p1/ directory from the host) so
# the worker node can pick it up in scripts/setup_worker.sh.
install -m 644 /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Make kubectl (bundled with k3s, and already symlinked to
# /usr/local/bin/kubectl by the installer) usable without sudo.
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' /home/vagrant/.bashrc \
  || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc

echo "K3s server ready on ${NODE_IP} (interface ${IFACE})"
