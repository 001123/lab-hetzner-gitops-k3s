# lab-hetzner-gitops-k3s

k3s + ArgoCD GitOps on a single Hetzner CX33 VPS — monorepo, SOPS + AGE secrets,
GitHub as the single source of truth.

> Full plan: [`plan/init/01-plan.md`](https://github.com/001123/lab-hetzner-gitops-k3s) (local notes, not committed).

```
dev machine ──ansible──▶ VPS (k3s)          GitHub (this repo) ◀──push── you
                            │                      │
                            └── ArgoCD (folder sync, auto-sync, self-heal)
```

**Responsibility boundary**

| Tool | Owns |
|---|---|
| Ansible (`ansible/`) | *only* bootstrap: k3s, firewall, ArgoCD + KSOPS, age key on the VPS |
| ArgoCD (`cluster/`) | *everything* after bootstrap — no manual `kubectl apply` from Phase 3 on |
| SOPS + AGE | secrets at rest in git; decrypted by KSOPS at sync time |

## Layout

```
ansible/                     # bootstrap only (Phase 1–2)
├── inventory/               # hosts.yml + group_vars (all.sops.yml = secrets)
└── roles/                   # common, k3s_server, sops_age, argocd
cluster/
├── bootstrap/root-app/      # root app-of-apps (apply once: make argocd-bootstrap)
├── bootstrap/children/      # Application "platform" + ApplicationSet "apps"
├── platform/                # cert-manager (pinned chart) + ClusterIssuer
└── apps/demo-nginx/         # one folder = one ArgoCD app (add a folder = add an app)
scripts/                     # sops-encrypt.sh, get-kubeconfig.sh
.github/workflows/validate.yml
```

## Quickstart

```bash
# 0. prerequisites: age keypair (see "Secrets"), DNS A records already in place
make bootstrap          # k3s + ArgoCD + KSOPS  (idempotent)
make kubeconfig         # replace ~/.kube/config with the VPS kubeconfig
make argocd-bootstrap   # register the root app-of-apps (one-time)
make apps               # watch ArgoCD apps go Healthy
make validate           # kustomize build + ansible syntax check
```

| Command | What it does |
|---|---|
| `make bootstrap` | `ansible-playbook ansible/playbooks/site.yml` (k3s + ArgoCD) |
| `make bootstrap-k3s` / `make bootstrap-argocd` | one phase only |
| `make argocd-bootstrap` | `kubectl apply -k cluster/bootstrap/root-app` |
| `make sops-encrypt` | encrypt / re-key every `*.sops.yaml` / `*.sops.yml` |
| `make nodes` / `make apps` | cluster / ArgoCD status |
| `make validate` | local validation (also runs in CI on PR) |

## GitOps flow

1. `root` Application (app-of-apps) syncs `cluster/bootstrap/children` → creates
   the `platform` Application (sync-wave `-1`) and the `apps` ApplicationSet (wave `0`).
2. `platform` installs cert-manager (wave `-1`) then `ClusterIssuer/letsencrypt-staging` (wave `0`).
3. `apps` ApplicationSet uses a **git directory generator** on `cluster/apps/*`:
   every subfolder becomes one auto-synced, self-healing Application.
   Adding an app = commit `cluster/apps/<name>/` — nothing else.

ArgoCD reaches the repo through the public GitHub URL; `kustomize.buildOptions`
in `argocd-cm` enables KSOPS (`--enable-alpha-plugins --enable-exec`) and kustomize
helm inflation (`--enable-helm`).

## Secrets (SOPS + AGE)

- **Public key** lives in [`.sops.yaml`](.sops.yaml) (safe to publish).
- **Private key** lives only at `~/.config/sops/age/keys.txt` on the dev machine and
  `/var/lib/sops-age/age.agekey` on the VPS (owner uid 999 = argocd, chmod 600).
  **Back it up offline — losing it means re-creating every secret.**
- Encrypted files: `ansible/inventory/group_vars/all.sops.yml` (bootstrap secrets)
  and `cluster/apps/*/secret.sops.yaml` (workload secrets, decrypted by KSOPS in
  argocd-repo-server at sync time).
- ArgoCD admin login: `admin` / `argocd_admin_password` in `all.sops.yml`
  (`sops -d ansible/inventory/group_vars/all.sops.yml`).

## Notes & deviations from the plan

- **kubeconfig**: written to `~/.kube/hetzner-cx33-nbg.yaml` so an existing
  `~/.kube/config` is never clobbered during bootstrap; `make kubeconfig`
  **replaces** `~/.kube/config` with it as context `hetzner-cx33-nbg`
  (previous file kept as `~/.kube/config.bak`).
- **firewall**: besides 22/80/443, port **6443** (k3s API) is opened from
  `ufw_allow_ssh_from` so `kubectl` works from the dev machine. Tighten that CIDR in
  `ansible/inventory/group_vars/all.yml` if your IP is static.
- **cert-manager** is inflated by kustomize `helmCharts` (pinned `v1.21.2`) instead of
  a separate `helm-release.yaml` — one ArgoCD source, version pinned in git.
- **KSOPS** installs only the `ksops` binary (`ksops install`, no `--with-kustomize`)
  and runs as a KRM exec plugin (`path: ksops` on `PATH`). The kustomize `v5.3.0`
  bundled by `--with-kustomize` shadows ArgoCD's own kustomize `v5.8.1` and breaks
  `helmCharts:` inflation with the image's helm v4 (removed `helm version -c`,
  upstream kustomize#6013).
- **`ksops-config/`** is not needed: the KSOPS wiring (init container
  `viaductoss/ksops:v4.5.1` + binary mounts + `SOPS_AGE_KEY_FILE`) is declarative in
  `ansible/roles/argocd/templates/argocd-values.yaml.j2`.
- **Let's Encrypt staging** is active (`letsencrypt-staging`); switch to production
  in `cluster/platform/cert-manager/cluster-issuer.yaml` + the ingress annotations
  once TLS is stable. Cloudflare DNS stays grey (DNS-only) until then.

## Troubleshooting

```bash
kubectl -n argocd get pods                     # repo-server = where KSOPS runs
kubectl -n argocd logs deploy/argocd-repo-server | grep -i ksops
kustomize build --enable-alpha-plugins --enable-exec cluster/apps/demo-nginx   # local KSOPS test
sops filestatus <file>                          # is it encrypted?
```
