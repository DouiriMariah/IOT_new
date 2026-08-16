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

# See setup_server.sh: retry to absorb occasional TCG network blips.
for attempt in 1 2 3 4 5; do
  if curl -sfL --retry 3 --retry-delay 3 https://get.k3s.io | \
    K3S_URL="https://${SERVER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-ip=${NODE_IP} \
      --flannel-iface=${IFACE}" \
    sh -; then
    break
  fi
  echo "k3s install attempt ${attempt} failed, retrying in 5s..." >&2
  sleep 5
  [ "$attempt" -lt 5 ] || exit 1
done

echo "K3s agent joined ${SERVER_IP} from ${NODE_IP} (interface ${IFACE})"
