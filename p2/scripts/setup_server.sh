#!/usr/bin/env bash
# Inception-of-Things - Part 2 - K3s server + 3 apps behind Ingress.
set -euxo pipefail

# The minimal Debian box ships without curl.
export DEBIAN_FRONTEND=noninteractive
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)

IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

# Wait for real internet connectivity before even trying to install -
# right after boot, the network can take a few seconds to come up.
for i in $(seq 1 30); do
  curl -sf --max-time 5 -o /dev/null https://get.k3s.io && break
  sleep 2
done

# The install script downloads the k3s binary from GitHub; on a
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

until k3s kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

grep -qxF 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' /home/vagrant/.bashrc \
  || echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/vagrant/.bashrc

# k3s ships with the Traefik Ingress controller enabled by default,
# it is what actually serves the Ingress resource defined below.
until k3s kubectl -n kube-system rollout status deploy/traefik --timeout=180s >/dev/null 2>&1; do
  sleep 2
done

k3s kubectl apply -f /tmp/confs/app1.yaml
k3s kubectl apply -f /tmp/confs/app2.yaml
k3s kubectl apply -f /tmp/confs/app3.yaml
k3s kubectl apply -f /tmp/confs/ingress.yaml

echo "K3s + 3 apps ready on ${NODE_IP} (interface ${IFACE})"
