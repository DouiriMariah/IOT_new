#!/usr/bin/env bash
# Inception-of-Things - Part 1 - K3s server (control-plane) provisioning.
set -euxo pipefail

# generic/debian12's default DNS servers (4.2.2.x) are unreachable from
# this network and cause intermittent "Could not resolve host" failures
# on every curl/apt call below. Public resolvers fix it at the root
# instead of just retrying around a broken lookup.
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf

# The minimal Debian box ships without curl.
export DEBIAN_FRONTEND=noninteractive
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)

# Modern Debian/Vagrant boxes use predictable interface names
# (enp0sX, ...) instead of eth0/eth1, so we detect the interface that
# actually carries our static IP instead of hard-coding a name.
IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

# Wait for real internet connectivity before even trying to install -
# right after boot, the network can take a few seconds to come up.
for i in $(seq 1 30); do
  curl -sf --max-time 5 -o /dev/null https://get.k3s.io && break
  sleep 2
done

# The install script itself downloads the k3s binary from GitHub; on a
# software-emulated (TCG) network this occasionally drops mid-transfer.
# Retry hard (up to 10 attempts, growing backoff) instead of failing
# the whole provisioning run over a transient blip.
for attempt in $(seq 1 10); do
  if timeout 180 curl -sfL --retry 5 --retry-delay 5 --retry-all-errors \
      --connect-timeout 15 https://get.k3s.io | \
    INSTALL_K3S_EXEC="server \
      --node-ip=${NODE_IP} \
      --advertise-address=${NODE_IP} \
      --flannel-iface=${IFACE} \
      --write-kubeconfig-mode=644" \
    sh -; then
    break
  fi
  echo "k3s install attempt ${attempt} failed, retrying..." >&2
  [ "$attempt" -lt 10 ] || exit 1
  sleep $(( attempt * 5 > 30 ? 30 : attempt * 5 ))
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
