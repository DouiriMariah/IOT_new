#!/usr/bin/env bash
# Inception-of-Things - Part 3 - creates the K3d cluster, installs Argo
# CD, and registers the GitOps Application that Argo CD will keep in
# sync with the p3/manifests/ folder of this repository.
set -euxo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

k3d cluster create --config "${ROOT}/confs/k3d-config.yaml"

kubectl apply -f "${ROOT}/confs/argocd-namespace.yaml"
kubectl apply -f "${ROOT}/confs/dev-namespace.yaml"

# --server-side: Argo CD's CRDs (e.g. applicationsets.argoproj.io) are
# too large for the "last-applied-configuration" annotation a regular
# `kubectl apply` writes (256KB limit); server-side apply avoids it.
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD to become available..."
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-repo-server

kubectl apply -f "${ROOT}/confs/application.yaml"

echo
echo "Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "Argo CD login: admin"
echo -n "Argo CD initial admin password: "
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
