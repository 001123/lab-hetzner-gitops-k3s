#!/usr/bin/env bash
#
# Encrypt (or re-key) all secret files (*.sops.yaml / *.sops.yml) using the age
# public keys from .sops.yaml. Usage:
#
#   scripts/sops-encrypt.sh              # every secret file tracked by git
#   scripts/sops-encrypt.sh path/to.yml  # just these files
#
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t files < <(git ls-files | grep -E '\.sops\.ya?ml$' | grep -vE '(^|/)\.sops\.ya?ml$' | sort)
  else
    mapfile -t files < <(find . -type f -name '*.sops.y*ml' \
      ! -name '.sops.yaml' ! -name '.sops.yml' \
      ! -path './.git/*' ! -path './plan/*' | sort)
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "no secret files found"
  exit 0
fi

for f in "${files[@]}"; do
  if sops --decrypt --output /dev/null "$f" >/dev/null 2>&1; then
    echo "re-key  $f"
    sops updatekeys --yes "$f"
  else
    echo "encrypt $f"
    tmp="$(mktemp)"
    sops --encrypt --output "$tmp" "$f"
    mv "$tmp" "$f"
    chmod 644 "$f"
  fi
done

echo "done. review with: git diff"
