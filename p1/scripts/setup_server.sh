#!/usr/bin/env bash
# Inception-of-Things - Part 1 - K3s server (control-plane) provisioning.
set -euxo pipefail

# The minimal Debian box ships without curl.
export DEBIAN_FRONTEND=noninteractive
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)

# Modern Debian/Vagrant boxes use predictable interface names
# (enp0sX, ...) instead of eth0/eth1, so we detect the interface that
# actually carries our static IP instead of hard-coding a name.
IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

# The install script itself downloads the k3s binary from GitHub; on a
# software-emulated (TCG) network this occasionally drops mid-transfer,
# so retry a few times instead of failing the whole provisioning run.
for attempt in 1 2 3 4 5; do
  if curl -sfL --retry 3 --retry-delay 3 https://get.k3s.io | \
    INSTALL_K3S_EXEC="server \
      --node-ip=${NODE_IP} \
      --advertise-address=${NODE_IP} \
      --flannel-iface=${IFACE} \
      --write-kubeconfig-mode=644" \
    sh -; then
    break
  fi
  echo "k3s install attempt ${attempt} failed, retrying in 5s..." >&2
  sleep 5
  [ "$attempt" -lt 5 ] || exit 1
done

# Wait until the API server actually answers before going further.
until k3s kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

# The join token itself (/var/lib/rancher/k3s/server/node-token) is
# picked up by the Vagrantfile's `trigger` right after this script
# finishes, and relayed to amatteiSW over SSH - no shared folder needed.

# Make kubectl (bundled with k3s, and already symlinked to
# /usr/local/bin/kubectl by the installer) usable without sudo.
grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' /home/vagrant/.bashrc \
  || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc

echo "K3s server ready on ${NODE_IP} (interface ${IFACE})"
