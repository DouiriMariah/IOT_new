#!/usr/bin/env bash
# Inception-of-Things - Part 2 - K3s server + 3 apps behind Ingress.
set -euxo pipefail

IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server \
    --node-ip=${NODE_IP} \
    --advertise-address=${NODE_IP} \
    --flannel-iface=${IFACE} \
    --write-kubeconfig-mode=644" \
  sh -

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

k3s kubectl apply -f /vagrant/confs/app1.yaml
k3s kubectl apply -f /vagrant/confs/app2.yaml
k3s kubectl apply -f /vagrant/confs/app3.yaml
k3s kubectl apply -f /vagrant/confs/ingress.yaml

echo "K3s + 3 apps ready on ${NODE_IP} (interface ${IFACE})"
