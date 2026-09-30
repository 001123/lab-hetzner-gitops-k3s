---
title: Tổng quan & Mục tiêu dự án
description: Bối cảnh, hạ tầng máy chủ Hetzner, cấu hình domain và bảng phiên bản pin cho phòng lab Hetzner k3s GitOps.
---

## 1. Bối cảnh & Mục tiêu dự án

Dự án này thiết lập một nền tảng GitOps chuẩn production trên 1 VPS Hetzner Cloud duy nhất, kết hợp Kubernetes rút gọn (**k3s**) và **ArgoCD** cùng cơ chế mã hoá bí mật không tin cậy (**SOPS + AGE**).

### Thông số hạ tầng máy chủ

* **Nhà cung cấp**: Hetzner Cloud (Trung tâm dữ liệu NBG1 - Nuremberg, Đức)
* **Loại máy chủ**: CX33 (2 vCPU / 8 GB RAM / 80 GB NVMe SSD)
* **Hệ điều hành**: Ubuntu 24.04.1 LTS
* **Kết nối SSH**: SSH alias `hetzner-cx33-nbg` (User: `root`, IP: `188.245.30.55`)
* **Môi trường chạy**: Docker CE 27.5.1 đã cài sẵn trên image Ubuntu của Hetzner. k3s vận hành containerd độc lập nên không xảy ra xung đột tài nguyên.

### Quản lý Tên miền & DNS

* **Apex Domain**: `timi.io.vn` (Quản lý qua Cloudflare, Zone ID `61a104b48738150008058d14de5e5110`)
* **Các subdomain chính**:
  * `argocd.timi.io.vn` → Giao diện và API ArgoCD
  * `demo-nginx.timi.io.vn` → Ứng dụng mẫu kiểm thử pipeline GitOps
* **Công cụ DNS**: Quản lý trực tiếp từ máy local qua Cloudflare CLI `cf` (`v1.0.0-beta.6`). Khi bootstrap ban đầu, các bản ghi DNS được đặt ở chế độ Grey Cloud (DNS-only) để đảm bảo Let's Encrypt HTTP-01 challenge hoạt động thông suốt.

---

## 2. Bảng phiên bản Pin (Pinned Versions)

Nhằm đảm bảo tính tái lập và tránh sai lệch phiên bản (drift), tất cả các thành phần cốt lõi đều được pin phiên bản chính xác:

| Thành phần | Phiên bản | Ghi chú & Phạm vi |
|---|---|---|
| **k3s** | `v1.37.0+k3s1` | Cài đặt qua script chính thức với biến `INSTALL_K3S_VERSION` |
| **Argo CD** | `v3.5.3` | Triển khai qua Helm chart `argo-cd` **10.9.4** |
| **cert-manager** | `v1.17.1` | Quản lý và gia hạn chứng chỉ SSL tự động Let's Encrypt |
| **SOPS** | `v3.13.3` | Mã hoá secret ở local và giải mã trên cụm |
| **AGE** | `v1.3.2` | Tạo cặp khoá và định danh bảo mật cho SOPS |
| **KSOPS** | `v4.5.1` | Image plugin distroless chạy trong pod `argocd-repo-server` |
| **Ansible** | `14.4.0` (core 2.21.4) | Điều phối quá trình bootstrap từ máy tính local |
| **kubectl** | `v1.37.1` | CLI local khớp minor version với cụm k3s |
| **Helm** | `v4.3.0` | Công cụ đóng gói và cài đặt Helm chart |
| **Kustomize** | `v5.8.1` | Engine dựng manifest và generator |

---

## 3. Các quyết định kiến trúc cốt lõi

1. **Mô hình Monorepo**: Toàn bộ mã nguồn Ansible, manifest hạ tầng cụm và các ứng dụng người dùng đều tập trung trong một repo Git duy nhất (`001123/lab-hetzner-gitops-k3s`).
2. **Ranh giới trách nhiệm rõ ràng**:
   * **Ansible** chỉ thực hiện nhiệm vụ bootstrap ban đầu (cấu hình firewall UFW, tối ưu OS, cài k3s và khởi tạo ArgoCD).
   * **ArgoCD** toàn quyền sở hữu và đồng bộ trạng thái cụm sau khi bootstrap hoàn tất. Không can thiệp thủ công bằng lệnh `kubectl apply`.
3. **Mã hoá Secret phi tập trung**: Tuyệt đối không commit secret dạng plaintext lên Git. Secret được mã hoá cục bộ bằng SOPS + AGE, lưu trữ an toàn trong Git public và KSOPS tự động giải mã trực tiếp trong cụm k3s.
4. **App-of-Apps & ApplicationSet**:
   * Ứng dụng hạ tầng hệ thống (Traefik, cert-manager) được quản lý theo mô hình **App-of-Apps**.
   * Các ứng dụng nghiệp vụ người dùng tại thư mục `cluster/apps/*` được ArgoCD tự động phát hiện và đồng bộ thông qua **ApplicationSet** dạng Git directory.
