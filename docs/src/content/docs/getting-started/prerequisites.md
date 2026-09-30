---
title: Prerequisites & Local Toolchain
description: Required local tools, version verification via mise/brew, SSH setup, and AGE key generation.
---

## 1. Local Toolchain Setup

To operate and maintain this GitOps lab, your local workstation requires several CLI utilities. It is strongly recommended to manage runtime versions using [mise-en-place](https://mise.jdx.dev/) and Homebrew.

### Verified Tools & Versions

Ensure your local environment matches the pinned toolchain:

| Tool | Recommended Installation | Verification Command |
|---|---|---|
| `kubectl` | `mise use kubectl@1.37.1` | `kubectl version --client` |
| `kustomize` | `mise use kustomize@5.8.1` | `kustomize version` |
| `ksops` | `mise use ksops@4.5.1` | `mise ls ksops` *(no `--version` flag)* |
| `helm` | `mise use helm@4.3.0` | `helm version --short` |
| `ansible` | `mise use pipx:ansible@14.4.0` | `ansible --version` |
| `sops` | `brew install sops` (`v3.13.3`) | `sops --version` |
| `age` | `brew install age` (`v1.3.2`) | `age --version` |
| `cf` | Cloudflare CLI (`cf@1.0.0-beta.6`) | `cf --version` |

---

## 2. SSH Host Configuration

Before executing Ansible playbooks, verify that your workstation can authenticate to the Hetzner CX33 server via SSH without interactive password prompts.

Add the following block to `~/.ssh/config`:

```ssh-config
Host hetzner-cx33-nbg
    HostName 188.245.30.55
    User root
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Test the connection:

```bash
ssh hetzner-cx33-nbg "uname -a && docker --version"
```

Expected output:
```text
Linux docker-ce-ubuntu-8gb-nbg1-1 6.8.0-... x86_64 Ubuntu 24.04.1 LTS
Docker version 27.5.1, build ...
```

---

## 3. Cloudflare DNS Configuration

Ensure that DNS records for both subdomains are created and pointing to `188.245.30.55` with **DNS-only (Grey Cloud)** status initially.

Verify DNS propagation using DNS-over-HTTPS (DoH):

```bash
# Verify argocd.timi.io.vn
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=argocd.timi.io.vn&type=A' | jq .

# Verify demo-nginx.timi.io.vn
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=demo-nginx.timi.io.vn&type=A' | jq .
```

Both queries must return an Answer record with IP `188.245.30.55`.

---

## 4. Generating the AGE Keypair

SOPS relies on an AGE public/private keypair. The private key must never be checked into Git.

1. Create a secure local directory:
   ```bash
   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
   ```

2. Generate the keypair:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. Extract the public key:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Example output: age13hphavvlee240rq0j42j60mqxj8s4k9tp473g076xl5z35p8mgjqx29stw
   ```

:::caution[Backup Private Key Offline]
Back up your private key `keys.txt` to a secure offline vault or password manager immediately. If this key is lost, encrypted secrets cannot be recovered!
:::
