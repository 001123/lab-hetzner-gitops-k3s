---
title: Multica Runbook (Self-Hosted AI-Agent Workspace)
description: Deploying, logging in, upgrading, and operating the Multica app from cluster/apps/multica via GitOps.
---

## 1. Overview

[Multica](https://github.com/multica-ai/multica) is a self-hosted workspace where you assign
issues to AI coding agents (Claude Code, Codex, Cursor, …) the way you would to a teammate.
It runs entirely on this cluster:

| Piece | What it is |
|---|---|
| `multica-frontend` | Next.js web UI — `https://multica.timi.io.vn` |
| `multica-backend` | Go API + WebSocket server — `https://api.multica.timi.io.vn` |
| `multica-postgres` | PostgreSQL 17 (`pgvector/pgvector:pg17`) on a 10Gi `local-path` PVC |
| `multica-secrets` | SOPS-encrypted Secret (JWT, DB password, optional keys) — the chart never templates it |
| agent daemon | Runs on **your own machine**, not in the cluster; it spawns the agent CLIs |

Everything except the daemon is managed by ArgoCD from `cluster/apps/multica/` — the `apps`
ApplicationSet folder-syncs the directory automatically. The official OCI chart
(`oci://ghcr.io/multica-ai/charts/multica`) is inflated by kustomize `helmCharts` at sync time.

---

## 2. Deploy (GitOps)

Deployment is just the directory `cluster/apps/multica/`:

```text
cluster/apps/multica/
├── kustomization.yaml      # helmCharts: oci chart 0.6.1 + valuesInline
├── namespace.yaml
├── secret-generator.yaml   # KSOPS generator
└── secret.sops.yaml        # Secret multica-secrets (encrypted at rest)
```

1. **DNS** (prerequisite): A records `multica.timi.io.vn` and `api.multica.timi.io.vn`
   → `188.245.30.55`, Cloudflare **DNS-only (grey)**.
2. **TLS**: the chart's Ingresses carry
   `cert-manager.io/cluster-issuer: letsencrypt-production`; cert-manager issues one SAN
   certificate (`multica-tls`) covering both hosts.
3. **Secrets**: edit `secret.sops.yaml` with `sops -d`, then `make sops-encrypt`
   (or `./scripts/sops-encrypt.sh cluster/apps/multica/secret.sops.yaml`). Keys:

   | Key | Required | Purpose |
   |---|---|---|
   | `JWT_SECRET` | yes | auth tokens; backend refuses to boot without it |
   | `POSTGRES_PASSWORD` | yes | built-in postgres |
   | `RESEND_API_KEY` | no | email login codes; empty → code printed in backend logs |
   | `GOOGLE_CLIENT_SECRET` | no | Google OAuth login |
   | `CLOUDFRONT_PRIVATE_KEY` | no | S3/CloudFront uploads (unused — local uploads PVC) |
   | `MULTICA_DEV_VERIFICATION_CODE` | no | fixed login code; **keep empty on public instances** |
   | `MULTICA_VCS_SECRET_KEY` | no | enables Gitea/Forgejo/GitLab VCS integration |

4. Commit & push; ArgoCD syncs within ~3 minutes. First backend boot can take a few minutes
   while it waits for PostgreSQL and runs migrations (startupProbe absorbs it).

Verify:

```bash
make apps                                          # app multica: Synced/Healthy
kubectl -n multica get pods,ingress,pvc
curl https://api.multica.timi.io.vn/healthz        # {"status":"ok","checks":{"db":"ok","migrations":"ok"}}
```

---

## 3. Log In

`APP_ENV=production` with no Resend key means the verification code is printed in the
backend logs:

```bash
kubectl -n multica logs deploy/multica-backend | grep "Verification code"
```

To switch to real email codes later: put a `re_...` key into `RESEND_API_KEY`
(`sops -d` / edit / `make sops-encrypt`), commit, then restart the backend pod once the
Secret is synced. To lock the instance down after bootstrapping, set
`backend.config.disableWorkspaceCreation: true` in `kustomization.yaml` — users can then
only join by invitation.

---

## 4. CLI & Agent Daemon

The daemon runs on a developer machine (with at least one agent CLI such as `claude` or
`codex` installed and signed in):

```bash
brew install multica-ai/tap/multica
multica setup self-host \
  --server-url https://api.multica.timi.io.vn \
  --app-url https://multica.timi.io.vn
multica daemon status        # machine appears under Settings -> Runtimes
```

Then create an agent in the web UI and assign it an issue — it picks the work up on the
daemon's machine and reports back on the board.

### Ansible: connect the VPS as a runtime

The repo ships an idempotent playbook (role `multica_cli`, target: the VPS) that installs
the pinned `multica` CLI from GitHub Releases, points it at `api.multica.timi.io.vn`,
logs in with a personal access token, and runs the daemon under a systemd unit
(`multica-daemon.service`) so it survives reboots.

1. Create a personal access token in the web UI (**Settings → API Tokens**), then put it
   into the SOPS vars: `sops ansible/inventory/group_vars/all.sops.yml` →
   `multica_api_token: "mul_..."`.
2. Run `make multica-daemon` (safe to re-run — a second run is a no-op).
3. Verify on the VPS: `systemctl is-active multica-daemon` and `multica daemon status`.

```bash
make multica-daemon                                        # install / update
ssh hetzner-cx33-nbg "journalctl -u multica-daemon -n 50"  # daemon logs
```

Notes:

- The role installs **only** the Multica CLI + daemon. It registers one runtime per agent
  CLI already present on the machine — install one (e.g. `claude`, `codex`) and sign it in
  to let agents execute on the VPS.
- **Upgrade** = bump `multica_cli_version` in `ansible/inventory/group_vars/all.yml`
  (keep it in sync with the server chart version) and re-run the playbook.
- **Expired token** = re-create it in the web UI, update `multica_api_token`, re-run.

---

## 5. Upgrade & Operations

- **Upgrade** = bump `version:` in the `helmCharts` block (chart version tracks the Git tag
  without the leading `v`; app image tags follow `Chart.appVersion`) + `make validate` +
  commit. Roll back with the normal ArgoCD history if needed.
- **Telemetry** is disabled (`backend.config.doNotTrack: "1"` in `kustomization.yaml`).
- **Backups** that matter: the postgres PVC (`multica-postgres-data`) and the uploads PVC
  (`multica-backend-uploads`), plus the SOPS age key (without it the secrets are gone).
- **Removing the app**: the Application has a finalizer and the backend Deployment uses
  `strategy: Recreate` with PVCs — see the pre-delete-finalizer note in the repo README if
  you move/delete the folder, and delete the namespace to wipe data.
- **License**: Multica is source-available (Apache 2.0 + additional conditions restricting
  hosted/Commercial embedding) — self-hosting is fine; read `LICENSE` before offering it as
  a service.
