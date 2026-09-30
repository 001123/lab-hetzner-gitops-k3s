---
title: Các vấn đề thường gặp & Ghi chú xử lý lỗi
description: Hướng dẫn xử lý sự cố lỗi distroless của KSOPS, lỗi cấp phát chứng chỉ Let's Encrypt, xung đột thứ tự sync wave và cứu hộ SSH.
---

## 1. Lỗi InitContainer KSOPS v4.5.1 (Image Distroless)

### Hiện tượng
Pod `argocd-repo-server` bị kẹt ở trạng thái `Init:CrashLoopBackOff` với dòng log báo lỗi:
```text
container_linux.go: starting container process caused: exec: "sh": executable file not found in $PATH
```

### Nguyên nhân
Từ phiên bản KSOPS `v4.4`, image được chuyển sang nền tảng **Google Distroless** (không chứa shell hệ thống). Cách viết initContainer truyền thống chạy lệnh shell (`sh -c "cp /usr/local/bin/ksops /custom-tools/"`) sẽ lập tức gãy đổ do không tìm thấy binary `sh`.

### Cách khắc phục
Cấu hình initContainer chạy trực tiếp binary `ksops` với subcommand cài đặt được tích hợp sẵn:
```yaml
initContainers:
  - name: install-ksops
    image: viaductoss/ksops:v4.5.1
    command: ["ksops"]
    args: ["install", "--with-kustomize", "/custom-tools"]
    volumeMounts:
      - mountPath: /custom-tools
        name: custom-tools
```
Tham số `--with-kustomize` là bắt buộc vì ArgoCD đi kèm một bản binary Kustomize riêng.

---

## 2. Let's Encrypt Rate Limits & Thất bại HTTP-01 Challenge

### Hiện tượng
Chứng chỉ SSL bị kẹt ở trạng thái `Issuing` hoặc ACME challenge báo quá thời gian chờ (timeout):
```text
Waiting for HTTP-01 challenge propagation
```

### Các bước kiểm tra & khắc phục
1. **Cấu hình Cloudflare Proxy**:
   Đảm bảo bản ghi DNS cho `argocd.timi.io.vn` và `demo-nginx.timi.io.vn` ban đầu được để ở chế độ **Grey Cloud (DNS-only)**. Sau khi chứng chỉ đã cấp phát thành công, bạn có thể bật lại Cloudflare Proxy (Orange Cloud) và đặt chế độ SSL là **Full (strict)** để tránh lỗi redirect loop.
2. **Tránh Rate Limit của Let's Encrypt**:
   Trong quá trình thử nghiệm ban đầu, luôn trỏ ClusterIssuer tới môi trường **Staging** của Let's Encrypt (`https://acme-staging-v02.api.letsencrypt.org/directory`). Khi hệ thống đã hoạt động ổn định mới chuyển sang Production.

---

## 3. Lỗi tạm thời không tìm thấy `ClusterIssuer`

### Hiện tượng
ArgoCD báo lỗi sync cụm trong lần đầu tiên chạy:
```text
the server could not find the requested resource (post clusterissuers.cert-manager.io)
```

### Nguyên nhân & Xử lý
Tài nguyên CRD của cert-manager chưa kịp đăng ký xong vào Kubernetes API thì manifest `ClusterIssuer` đã được nạp vào.
* Sử dụng sync wave: Gán `argocd.argoproj.io/sync-wave: "-1"` cho deployment của cert-manager và `argocd.argoproj.io/sync-wave: "0"` cho `ClusterIssuer`.
* Nhờ cơ chế tự phục hồi (`selfHeal`), ArgoCD sẽ tự động thử lại sau vài giây và cụm sẽ tự hội tụ về trạng thái xanh (Healthy).

---

## 4. Xử lý sự cố khoá cổng SSH / Firewall

### Hiện tượng
Không thể SSH vào máy chủ sau khi chạy role Ansible `common`.

### Nguyên nhân
Tường lửa UFW được kích hoạt nhưng chưa cấu hình cho phép cổng 22 hoặc IP dev kết nối.

### Cứu hộ khẩn cấp
1. Đăng nhập vào trang quản trị [Hetzner Cloud Console](https://console.hetzner.cloud/).
2. Mở tính năng **VNC Web Console** cho máy chủ `hetzner-cx33-nbg`.
3. Kiểm tra và mở lại cổng SSH trực tiếp từ console:
   ```bash
   sudo ufw status verbose
   sudo ufw allow 22/tcp
   sudo ufw reload
   ```

---

## 5. Giám sát tài nguyên máy chủ Single-Node

VPS CX33 có 2 vCPU và 8GB RAM. Toàn bộ control plane k3s, Traefik, cert-manager và ArgoCD chỉ chiếm khoảng 1.5GB đến 2.0GB RAM:

```bash
# Giám sát tải tài nguyên trên node
kubectl top node

# Theo dõi mức tiêu thụ RAM của từng pod trên toàn cụm
kubectl top pods -A --sort-by=memory
```
