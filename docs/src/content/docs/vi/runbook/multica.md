---
title: Runbook Multica (AI-Agent Workspace Tự Host)
description: Triển khai, đăng nhập, nâng cấp và vận hành app Multica từ cluster/apps/multica bằng GitOps.
---

## 1. Tổng quan

[Multica](https://github.com/multica-ai/multica) là workspace tự host để giao issue cho các
AI coding agent (Claude Code, Codex, Cursor, …) như giao việc cho đồng nghiệp. Toàn bộ chạy
trên cluster này:

| Thành phần | Là gì |
|---|---|
| `multica-frontend` | Web UI Next.js — `https://multica.timi.io.vn` |
| `multica-backend` | Go API + WebSocket — `https://api.multica.timi.io.vn` |
| `multica-postgres` | PostgreSQL 17 (`pgvector/pgvector:pg17`) trên PVC `local-path` 10Gi |
| `multica-secrets` | Secret mã hóa SOPS (JWT, mật khẩu DB, key tùy chọn) — chart không template secret này |
| agent daemon | Chạy trên **máy của bạn**, không trong cluster; nó gọi các agent CLI |

Mọi thứ trừ daemon được ArgoCD quản lý từ `cluster/apps/multica/` — ApplicationSet `apps`
folder-sync thư mục này tự động. Chart OCI chính thức
(`oci://ghcr.io/multica-ai/charts/multica`) được kustomize `helmCharts` inflate lúc sync.

---

## 2. Triển khai (GitOps)

Triển khai = thư mục `cluster/apps/multica/`:

```text
cluster/apps/multica/
├── kustomization.yaml      # helmCharts: chart OCI 0.6.1 + valuesInline
├── namespace.yaml
├── secret-generator.yaml   # KSOPS generator
└── secret.sops.yaml        # Secret multica-secrets (mã hóa khi lưu trữ)
```

1. **DNS** (điều kiện tiên quyết): A record `multica.timi.io.vn` và `api.multica.timi.io.vn`
   → `188.245.30.55`, Cloudflare **DNS-only (mây xám)**.
2. **TLS**: các Ingress của chart mang annotation
   `cert-manager.io/cluster-issuer: letsencrypt-production`; cert-manager cấp một chứng chỉ
   SAN (`multica-tls`) cho cả 2 host.
3. **Secrets**: sửa `secret.sops.yaml` bằng `sops -d`, rồi `make sops-encrypt`
   (hoặc `./scripts/sops-encrypt.sh cluster/apps/multica/secret.sops.yaml`). Các key:

   | Key | Bắt buộc | Công dụng |
   |---|---|---|
   | `JWT_SECRET` | có | token xác thực; backend từ chối boot nếu thiếu |
   | `POSTGRES_PASSWORD` | có | postgres nội bộ |
   | `RESEND_API_KEY` | không | mã đăng nhập qua email; để trống → mã in trong log backend |
   | `GOOGLE_CLIENT_SECRET` | không | đăng nhập Google OAuth |
   | `CLOUDFRONT_PRIVATE_KEY` | không | uploads S3/CloudFront (không dùng — dùng PVC local) |
   | `MULTICA_DEV_VERIFICATION_CODE` | không | mã đăng nhập cố định; **giữ trống trên instance công khai** |
   | `MULTICA_VCS_SECRET_KEY` | không | bật tích hợp VCS Gitea/Forgejo/GitLab |

4. Commit & push; ArgoCD sync trong ~3 phút. Lần boot đầu của backend có thể mất vài phút
   chờ PostgreSQL + chạy migrations (startupProbe chống restart).

Kiểm tra:

```bash
make apps                                          # app multica: Synced/Healthy
kubectl -n multica get pods,ingress,pvc
curl https://api.multica.timi.io.vn/healthz        # {"status":"ok","checks":{"db":"ok","migrations":"ok"}}
```

---

## 3. Đăng nhập

`APP_ENV=production` và không có key Resend → mã xác thực được in trong log backend:

```bash
kubectl -n multica logs deploy/multica-backend | grep "Verification code"
```

Muốn gửi email thật sau này: thêm key `re_...` vào `RESEND_API_KEY`
(`sops -d` / sửa / `make sops-encrypt`), commit, rồi restart pod backend sau khi Secret sync.
Muốn khóa instance sau khi bootstrap: đặt `backend.config.disableWorkspaceCreation: true`
trong `kustomization.yaml` — user chỉ tham gia được qua lời mời.

---

## 4. CLI & Agent Daemon

Daemon chạy trên máy dev (cần ít nhất một agent CLI như `claude` hoặc `codex` đã cài + đăng
nhập):

```bash
brew install multica-ai/tap/multica
multica setup self-host \
  --server-url https://api.multica.timi.io.vn \
  --app-url https://multica.timi.io.vn
multica daemon status        # máy hiện trong Settings -> Runtimes
```

Sau đó tạo agent trong web UI và giao issue — agent tự nhận việc trên máy chạy daemon và báo
cáo lên board.

---

## 5. Nâng cấp & Vận hành

- **Nâng cấp** = bump `version:` trong block `helmCharts` (version chart = Git tag bỏ chữ
  `v` đầu; tag ảnh app theo `Chart.appVersion`) + `make validate` + commit. Rollback theo
  lịch sử ArgoCD như bình thường.
- **Telemetry** đang tắt (`backend.config.doNotTrack: "1"` trong `kustomization.yaml`).
- **Backup** đáng quan tâm: PVC postgres (`multica-postgres-data`), PVC uploads
  (`multica-backend-uploads`) và age key SOPS (mất key = mất toàn bộ secret).
- **Gỡ app**: Application có finalizer và backend Deployment dùng `strategy: Recreate` kèm
  PVC — xem note pre-delete-finalizer trong README repo nếu chuyển/xóa thư mục; xóa
  namespace để xóa dữ liệu.
- **Giấy phép**: Multica là source-available (Apache 2.0 + điều kiện bổ sung hạn chế hosted
  service) — self-host OK; đọc `LICENSE` trước khi cung cấp cho bên thứ ba.
