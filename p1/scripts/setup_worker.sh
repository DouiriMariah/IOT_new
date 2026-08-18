#!/usr/bin/env bash
# Inception-of-Things - Part 1 - K3s agent (worker) provisioning.
set -euxo pipefail

# The minimal Debian box ships without curl.
export DEBIAN_FRONTEND=noninteractive
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)

IFACE=$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ "^"ip"/" {print $2; exit}')

# The Vagrantfile's "file" provisioner uploads the server's join token
# to /tmp/node-token over SSH (see p1/Vagrantfile) before this script runs.
K3S_TOKEN=$(cat /tmp/node-token)
if [ -z "${K3S_TOKEN}" ]; then
  echo "FATAL: /tmp/node-token is empty - amatteiS's token wasn't ready" \
       "when this file was uploaded. This should not happen with" \
       "VAGRANT_NO_PARALLEL forced in the Vagrantfile; if it does," \
       "run: vagrant provision amatteiS && vagrant provision amatteiSW" >&2
  exit 1
fi

# Wait for real internet connectivity before even trying to install -
# right after boot, the network can take a few seconds to come up.
for i in $(seq 1 30); do
  curl -sf --max-time 5 -o /dev/null https://get.k3s.io && break
  sleep 2
done

# See setup_server.sh: retry hard to absorb TCG network blips. Up to
# 10 attempts with growing backoff (5s, 10s, ... capped at 30s) and a
# bounded per-attempt timeout so one stuck attempt can't stall the rest.
for attempt in $(seq 1 10); do
  if timeout 180 curl -sfL --retry 5 --retry-delay 5 --retry-all-errors \
      --connect-timeout 15 https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-ip=${NODE_IP} \
      --flannel-iface=${IFACE}" \
    sh -; then
    break
  fi
  echo "k3s install attempt ${attempt} failed, retrying..." >&2
  [ "$attempt" -lt 10 ] || exit 1
  sleep $(( attempt * 5 > 30 ? 30 : attempt * 5 ))
done

echo "K3s agent joined ${SERVER_IP} from ${NODE_IP} (interface ${IFACE})"
