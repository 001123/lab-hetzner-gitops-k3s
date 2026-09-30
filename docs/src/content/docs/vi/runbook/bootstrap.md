---
title: Runbook Khởi tạo cụm & Bootstrap ArgoCD
description: Hướng dẫn từng bước chạy Ansible để cài đặt k3s, ArgoCD, KSOPS và cấp phát chứng chỉ TLS.
---

## 1. Kiểm tra điều kiện tiên quyết trước khi chạy

Trước khi chạy playbook khởi tạo, hãy đảm bảo các điều kiện sau đã sẵn sàng:

1. Kết nối SSH tới VPS Hetzner CX33 thành công:
   ```bash
   ssh hetzner-cx33-nbg "uname -a"
   ```
2. File khoá bí mật AGE tồn tại trên máy local tại `~/.config/sops/age/keys.txt`:
   ```bash
   test -f ~/.config/sops/age/keys.txt && echo "Đã có private key"
   ```
3. Mã hoá lại các file biến nếu có thay đổi:
   ```bash
   make sops-encrypt
   ```

---

## 2. Thực thi quy trình Bootstrap

Thực hiện kiểm tra cú pháp và triển khai toàn bộ hạ tầng bằng Ansible (lệnh có tính chất idempotent, chạy lại an toàn):

```bash
# 1. Kiểm tra cú pháp manifest Kustomize và cú pháp playbook
make validate

# 2. Chạy playbook bootstrap hoàn chỉnh
make bootstrap

# 3. Kiểm tra trạng thái node từ máy local
make nodes
```

Kết quả mong đợi khi kiểm tra node:
```text
NAME                            STATUS   ROLES                  AGE   VERSION
docker-ce-ubuntu-8gb-nbg1-1     Ready    control-plane,master   2m    v1.37.0+k3s1
```

---

## 3. Quản lý file Kubeconfig

Playbook Ansible sẽ tải file kubeconfig về một đường dẫn riêng biệt: `~/.kube/hetzner-cx33-nbg.yaml` để tránh ghi đè làm mất cấu hình các cụm k8s khác trên máy của bạn.

Để tương tác với cụm:

```bash
# Cách 1: Xuất biến môi trường cho phiên làm việc hiện tại
export KUBECONFIG=~/.kube/hetzner-cx33-nbg.yaml

# Cách 2: Sao lưu file cũ và đặt cụm này làm kubeconfig mặc định
make kubeconfig
```

---

## 4. Xác minh hệ thống ArgoCD

Sau khi `make bootstrap` hoàn tất, kiểm tra toàn bộ các pod của ArgoCD đã ở trạng thái Running:

```bash
kubectl get pods -n argocd
```

Kết quả mẫu:
```text
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3m
argocd-applicationset-controller-...                1/1     Running   0          3m
argocd-dex-server-...                               1/1     Running   0          3m
argocd-redis-...                                    1/1     Running   0          3m
argocd-repo-server-...                              1/1     Running   0          3m
argocd-server-...                                   1/1     Running   0          3m
```

### Kiểm tra Ingress & Chứng chỉ TLS

Kiểm tra endpoint công khai của ArgoCD qua giao thức HTTPS:

```bash
curl -sI https://argocd.timi.io.vn
```

Headers trả về mẫu:
```http
HTTP/2 200
server: Cowboy / Traefik
strict-transport-security: max-age=63072000; includeSubDomains; preload
```

### Đăng nhập trang quản trị ban đầu

* **Địa chỉ UI**: `https://argocd.timi.io.vn`
* **Tài khoản**: `admin`
* **Mật khẩu**: Lấy từ giá trị đã mã hoá trong file `ansible/inventory/group_vars/all.sops.yml` (`argocd_admin_password`).
