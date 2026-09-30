---
title: Yêu cầu tiên quyết & Công cụ Local
description: Danh mục công cụ dev, kiểm tra phiên bản qua mise/brew, cấu hình SSH và khởi tạo cặp khoá AGE.
---

## 1. Cài đặt bộ công cụ Local

Để quản trị và vận hành phòng lab GitOps này, máy tính dev của bạn cần chuẩn bị các CLI tool. Bạn nên quản lý phiên bản các công cụ này bằng [mise-en-place](https://mise.jdx.dev/) và Homebrew để đảm bảo tính nhất quán.

### Bảng công cụ & Lệnh kiểm tra

Đảm bảo môi trường máy local khớp hoàn toàn với các phiên bản đã pin:

| Công cụ | Khuyến nghị cài đặt | Lệnh kiểm tra phiên bản |
|---|---|---|
| `kubectl` | `mise use kubectl@1.37.1` | `kubectl version --client` |
| `kustomize` | `mise use kustomize@5.8.1` | `kustomize version` |
| `ksops` | `mise use ksops@4.5.1` | `mise ls ksops` *(lưu ý: ksops không có flag `--version`)* |
| `helm` | `mise use helm@4.3.0` | `helm version --short` |
| `ansible` | `mise use pipx:ansible@14.4.0` | `ansible --version` |
| `sops` | `brew install sops` (`v3.13.3`) | `sops --version` |
| `age` | `brew install age` (`v1.3.2`) | `age --version` |
| `cf` | Cloudflare CLI (`cf@1.0.0-beta.6`) | `cf --version` |

---

## 2. Cấu hình kết nối SSH máy chủ Hetzner

Trước khi thực thi Ansible playbook, bạn cần đảm bảo máy tính local có thể SSH vào VPS Hetzner CX33 bằng SSH key mà không bị hỏi mật khẩu tương tác.

Thêm đoạn cấu hình sau vào file `~/.ssh/config`:

```ssh-config
Host hetzner-cx33-nbg
    HostName 188.245.30.55
    User root
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Kiểm tra kết nối:

```bash
ssh hetzner-cx33-nbg "uname -a && docker --version"
```

Kết quả mong đợi:
```text
Linux docker-ce-ubuntu-8gb-nbg1-1 6.8.0-... x86_64 Ubuntu 24.04.1 LTS
Docker version 27.5.1, build ...
```

---

## 3. Xác thực bản ghi DNS Cloudflare

Đảm bảo cả 2 subdomain đã được trỏ tới địa chỉ IP `188.245.30.55` ở chế độ **DNS-only (Grey Cloud)** để chuẩn bị cho Let's Encrypt cấp SSL.

Kiểm tra phân giải DNS trực tiếp qua Cloudflare DNS-over-HTTPS (DoH):

```bash
# Kiểm tra subdomain argocd.timi.io.vn
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=argocd.timi.io.vn&type=A' | jq .

# Kiểm tra subdomain demo-nginx.timi.io.vn
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=demo-nginx.timi.io.vn&type=A' | jq .
```

Cả hai lệnh phải trả về trường Answer chứa IP `188.245.30.55`.

---

## 4. Khởi tạo cặp khoá bí mật AGE (1 lần duy nhất)

SOPS sử dụng cặp khoá Public / Private của AGE. Private key tuyệt đối không commit lên Git.

1. Tạo thư mục cấu hình bảo mật trên máy local:
   ```bash
   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
   ```

2. Tạo cặp khoá mới:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

3. Lấy Public Key để khai báo vào `.sops.yaml`:
   ```bash
   age-keygen -y ~/.config/sops/age/keys.txt
   # Ví dụ đầu ra: age13hphavvlee240rq0j42j60mqxj8s4k9tp473g076xl5z35p8mgjqx29stw
   ```

:::caution[Sao lưu Private Key Offline ngay]
Sao lưu ngay file private key `keys.txt` vào một nơi lưu trữ an toàn (USB hoặc trình quản lý mật khẩu). Nếu mất file khoá này, toàn bộ dữ liệu secret đã mã hoá sẽ không thể phục hồi!
:::
