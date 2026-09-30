#!/usr/bin/env bash
#
# Fetch the k3s kubeconfig from the VPS and MERGE it into ~/.kube/config as
# cluster/user/context `hetzner-cx33-nbg`. Never overwrites existing entries
# with other names. (The bootstrap also writes a standalone copy to
# ~/.kube/hetzner-cx33-nbg.yaml — see group_vars/all.yml.)
#
set -euo pipefail

HOST_ALIAS="hetzner-cx33-nbg"
SERVER_IP="188.245.30.55"
KCFG="$HOME/.kube/config"

TMP="$(mktemp)"
MERGED="$(mktemp)"
trap 'rm -f "$TMP" "$MERGED"' EXIT

echo "fetching /etc/rancher/k3s/k3s.yaml from $HOST_ALIAS ..."
ssh "$HOST_ALIAS" "cat /etc/rancher/k3s/k3s.yaml" > "$TMP"

# point the kubeconfig at the public IP instead of 127.0.0.1
sed -i.bak "s#server: https://127.0.0.1:6443#server: https://${SERVER_IP}:6443#" "$TMP"
rm -f "$TMP.bak"

# avoid clobbering same-named entries in ~/.kube/config
export KUBECONFIG="$TMP"
kubectl config rename-cluster default "$HOST_ALIAS" >/dev/null
kubectl config rename-user default "$HOST_ALIAS" >/dev/null
kubectl config rename-context default "$HOST_ALIAS" >/dev/null
unset KUBECONFIG

mkdir -p "$(dirname "$KCFG")"
touch "$KCFG"
chmod 600 "$KCFG"

KUBECONFIG="$KCFG:$TMP" kubectl config view --flatten > "$MERGED"
mv "$MERGED" "$KCFG"
chmod 600 "$KCFG"

echo "merged context '$HOST_ALIAS' into $KCFG"
echo "try: kubectl --context $HOST_ALIAS get nodes"
