#!/usr/bin/env bash
# Inception-of-Things - Part 3 - installs every tool needed for K3d + Argo CD.
# Idempotent: safe to re-run, only installs what is missing.
set -euxo pipefail

# ---- Docker (required by K3d, which runs K3s nodes as containers) ----
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker "${SUDO_USER:-vagrant}" || true
fi

# ---- kubectl ----
if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  curl -sLo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
fi

# ---- K3d ----
if ! command -v k3d >/dev/null 2>&1; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# ---- Argo CD CLI (handy to inspect/sync apps from the shell) ----
if ! command -v argocd >/dev/null 2>&1; then
  curl -sSL -o /usr/local/bin/argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /usr/local/bin/argocd
fi

echo "docker: $(docker --version)"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "k3d: $(k3d version)"
echo "argocd: $(argocd version --client --short 2>/dev/null || true)"
