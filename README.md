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
├── bootstrap/children/      # Application "platform", Application "infra", ApplicationSet "apps"
├── platform/                # TIER 1 — what other apps depend on: cert-manager + ClusterIssuer
├── infra/                   # TIER 2 — cluster-wide services (ONE Application "infra")
│   ├── victoria-metrics/    #   monitoring stack (pinned victoria-metrics-k8s-stack)
│   └── grafana/             #   dashboards UI (pinned grafana chart) — grafana.timi.io.vn
└── apps/                    # TIER 3 — user workloads: one folder = one ArgoCD app
    └── demo-nginx/
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

1. `root` Application (app-of-apps) syncs `cluster/bootstrap/children` in wave
   order → creates the `platform` Application (wave `-1`), the `infra`
   Application (wave `0`) and the `apps` ApplicationSet (wave `1`).
2. `platform` installs cert-manager (wave `-1`) then `ClusterIssuer/letsencrypt-production` (wave `0`).
3. `infra` deploys cluster-wide services from `cluster/infra/` as one Application;
   internal order via sync-waves: `victoria-metrics` (0) then `grafana` (1).
4. `apps` ApplicationSet uses a **git directory generator** on `cluster/apps/*`:
   every subfolder becomes one auto-synced, self-healing Application.
   Adding a user app = commit `cluster/apps/<name>/` — nothing else.

**How to classify a new component** (tiering):
- *Without it, other apps cannot run* (TLS, storage class, ingress...) → `platform/`
- *A shared service the cluster runs for itself* (monitoring, logging, backup...) → `infra/`
  (add the subfolder to `cluster/infra/kustomization.yaml`)
- *Business/demo workload* → `apps/`

ArgoCD reaches the repo through the public GitHub URL; `kustomize.buildOptions`
in `argocd-cm` enables KSOPS (`--enable-alpha-plugins --enable-exec`) and kustomize
helm inflation (`--enable-helm`).

## Secrets (SOPS + AGE)

- **Public key** lives in [`.sops.yaml`](.sops.yaml) (safe to publish).
- **Private key** lives only at `~/.config/sops/age/keys.txt` on the dev machine and
  `/var/lib/sops-age/age.agekey` on the VPS (owner uid 999 = argocd, chmod 600).
  **Back it up offline — losing it means re-creating every secret.**
- Encrypted files: `ansible/inventory/group_vars/all.sops.yml` (bootstrap secrets)
  and `cluster/apps/*/secret.sops.yaml` / `cluster/infra/*/secret.sops.yaml`
  (workload secrets, decrypted by KSOPS in
  argocd-repo-server at sync time).
- ArgoCD admin login: `admin` / `argocd_admin_password` in `all.sops.yml`
  (`sops -d ansible/inventory/group_vars/all.sops.yml`).

## Monitoring (VictoriaMetrics + Grafana)

- **VictoriaMetrics** (`cluster/infra/victoria-metrics`): `victoria-metrics-k8s-stack` —
  operator + VMSingle (storage/query, PVC 20Gi `local-path`, retention 1 month) +
  VMAgent + kube-state-metrics + node-exporter, scraping kubelet/cAdvisor/k3s components.
- **Grafana** (`cluster/infra/grafana`): `grafana.timi.io.vn` (Traefik + Let's Encrypt).
  Datasource trỏ VMSingle; dashboards đến từ sync-job của k8s-stack qua sidecar
  (ConfigMaps label `grafana_dashboard`). Login: `admin` / password trong
  `cluster/infra/grafana/secret.sops.yaml` (`sops -d cluster/infra/grafana/secret.sops.yaml`).

```bash
kubectl -n victoria-metrics get pods
kubectl -n victoria-metrics port-forward svc/vmsingle-vm 8428
curl 'localhost:8428/api/v1/query?query=up'          # VMUI/query locally
```

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
- **Let's Encrypt production** is active (`letsencrypt-production`); the staging
  issuer was replaced once TLS proved stable. Cloudflare DNS stays grey (DNS-only)
  until you enable proxy (orange) + SSL **Full (strict)**.
- **Monitoring charts are pinned** (kustomize `helmCharts`, inflated at sync time):
  `victoria-metrics-k8s-stack` `0.95.0` (VictoriaMetrics `v1.153.0`) and
  `grafana` `13.2.7` (Grafana `13.2.3`) — newest releases as of 2026-09-30.
  Grafana's newest charts live in `https://grafana-community.github.io/helm-charts`
  (chart version tracks the app version); the old `grafana.github.io/helm-charts`
  repo only ships Grafana 12.x. Upgrade = bump `version:` in the app's
  `kustomization.yaml` + `make validate`.
- **`includeCrds: true`** on the victoria-metrics chart is required: kustomize's
  helm inflation drops the chart `crds/` directory without it, and the
  VMSingle/VMAgent/VMAlert CRs then fail to apply.
- **VM operator webhook certs** come from cert-manager
  (`victoria-metrics-operator.admissionWebhooks.certManager.enabled: true`)
  instead of chart-generated self-signed certs — random certs would otherwise be
  re-rendered on every reconcile and keep the app OutOfSync forever.
- **Helm hooks under ArgoCD**: the dashboard sync-job (`post-install,post-upgrade`)
  is mapped to a PostSync hook and re-runs on each sync (needs egress to
  raw.githubusercontent.com for the dashboard sources); the operator cleanup
  (`pre-delete`) maps to PreDelete. Do not add `argocd.argoproj.io/hook`
  annotations to these apps — that disables the mapping.

## Troubleshooting

```bash
kubectl -n argocd get pods                     # repo-server = where KSOPS runs
kubectl -n argocd logs deploy/argocd-repo-server | grep -i ksops
kustomize build --enable-alpha-plugins --enable-exec cluster/apps/demo-nginx   # local KSOPS test
sops filestatus <file>                          # is it encrypted?
```
