#!/usr/bin/env bash
#
# Fetch the k3s kubeconfig from the VPS and REPLACE ~/.kube/config with it
# (cluster/user/context `hetzner-cx33-nbg`, set as current-context). The
# previous ~/.kube/config is kept as ~/.kube/config.bak. (The bootstrap also
# writes a standalone copy to ~/.kube/hetzner-cx33-nbg.yaml — see
# group_vars/all.yml.)
#
# Replace (not merge) on purpose: `kubectl config view --flatten` prefers the
# first KUBECONFIG file, so a merge would silently keep stale entries whenever
# the same context name already exists (e.g. after a k3s cert rotation).
#
set -euo pipefail

HOST_ALIAS="hetzner-cx33-nbg"
SERVER_IP="188.245.30.55"
KCFG="$HOME/.kube/config"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

echo "fetching /etc/rancher/k3s/k3s.yaml from $HOST_ALIAS ..."
ssh "$HOST_ALIAS" "cat /etc/rancher/k3s/k3s.yaml" > "$TMP"

# kubectl >= 1.37 dropped `config rename-cluster` / `config rename-user`, so do
# the renaming here. The patterns only touch whole `...: default` field lines in
# the machine-generated k3s.yaml — never the base64 cert/key blobs.
sed -i.bak -E \
  -e "s#server: https://127\.0\.0\.1:6443#server: https://${SERVER_IP}:6443#" \
  -e "s/^( *-? *)(cluster|user|name|current-context): default$/\1\2: ${HOST_ALIAS}/" \
  "$TMP"
rm -f "$TMP.bak"

grep -q "^current-context: ${HOST_ALIAS}$" "$TMP" || {
  echo "unexpected k3s.yaml format — nothing written to $KCFG" >&2
  exit 1
}

mkdir -p "$(dirname "$KCFG")"
if [ -f "$KCFG" ]; then
  cp -p "$KCFG" "$KCFG.bak"
  echo "previous $KCFG kept as $KCFG.bak"
fi
cp "$TMP" "$KCFG"
chmod 600 "$KCFG"

echo "installed context '$HOST_ALIAS' as current-context in $KCFG"
echo "try: kubectl get nodes"
