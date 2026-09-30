---
title: Triển khai Ứng dụng & Vận hành GitOps
description: Kích hoạt ứng dụng root, thêm app mới qua ApplicationSet và kiểm tra cơ chế tự phục hồi self-healing.
---

## 1. Khởi động Application Gốc (Root App)

Sau khi cụm k3s đã hoàn tất bootstrap, toàn bộ chu trình GitOps được kích hoạt bằng lệnh nạp application gốc:

```bash
kubectl apply -k cluster/bootstrap/root-app
```

Application `root-app` sẽ đồng bộ thư mục `cluster/bootstrap/children/`, lập tức sinh ra:
1. `platform`: Triển khai cert-manager và ClusterIssuer vào namespace `cert-manager`.
2. `apps`: Một ApplicationSet tự động theo dõi toàn bộ thư mục con trong `cluster/apps/*`.

---

## 2. Quy trình thêm ứng dụng mới vào cụm

Nhờ cơ chế Git directory generator của ApplicationSet (`path: cluster/apps/*`), việc đưa một dịch vụ mới lên cụm không đòi hỏi bạn phải chỉnh sửa bất kỳ cấu hình nào trên ArgoCD.

### Cấu trúc thư mục ứng dụng chuẩn

Để đưa một ứng dụng tên `my-service` vào hệ thống:

```text
cluster/apps/my-service/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
├── ingress.yaml
└── secret.sops.yaml          # Tuỳ chọn: secret runtime đã được mã hoá SOPS
```

### Ví dụ mẫu: `demo-nginx`

Trong repository đã có sẵn ứng dụng mẫu tại `cluster/apps/demo-nginx/`:
* Phục vụ trang HTML tuỳ biến qua ConfigMap.
* Secret mã hoá bằng SOPS trong `secret.sops.yaml`.
* Ingress trỏ domain `demo-nginx.timi.io.vn` với annotation tự động cấp phát TLS:
  ```yaml
  cert-manager.io/cluster-issuer: letsencrypt-prod
  ```

Commit và đẩy code lên GitHub:
```bash
git add cluster/apps/my-service
git commit -m "feat: onboard my-service via GitOps"
git push origin main
```

Trong vòng 3 phút (hoặc ngay lập tức nếu bạn bấm nút Refresh trên giao diện ArgoCD UI), ArgoCD sẽ tự động nhận diện thư mục mới, tạo Application tương ứng và deploy pod lên k3s.

---

## 3. Kiểm thử cơ chế Tự phục hồi (Self-Healing)

ArgoCD được bật đồng thời tính năng tự đồng bộ (auto-sync) và tự phục hồi khi có sai lệch (`selfHeal: true`).

### Bài test 1: Xoá pod thủ công
Xoá thử pod đang chạy của demo app:
```bash
kubectl delete pod -l app=demo-nginx -n demo-nginx
```
**Hiện tượng**: ReplicaSet lập tức tạo lại pod mới ngay sau vài giây.

### Bài test 2: Sửa đổi trái phép trạng thái cụm
Dùng lệnh `kubectl` để thay đổi số lượng replica ngoài luồng Git:
```bash
kubectl scale deployment demo-nginx --replicas=5 -n demo-nginx
```
**Hiện tượng**: ArgoCD phát hiện số replica trên cụm (`5`) không khớp với khai báo trên Git (`replicas: 1`), hệ thống sẽ lập tức can thiệp và scale ngược lại về `1`.

---

## 4. Chiến lược Rollback ứng dụng

Trong quy chuẩn GitOps, mọi thao tác rollback phải được thực hiện thông qua lịch sử commit của Git thay vì gõ lệnh trên cụm:

```bash
# Revert lại commit bị lỗi trên Git
git revert <commit-sha>
git push origin main
```

ArgoCD sẽ tự động đồng bộ lại trạng thái ổn định trước đó, đảm bảo lịch sử thay đổi luôn được lưu trữ minh bạch.
