---
title: Tài liệu Hetzner k3s GitOps
description: Hướng dẫn hoàn chỉnh triển khai cụm k3s single-node, ArgoCD GitOps, Traefik, cert-manager và mã hóa SOPS+AGE trên Hetzner Cloud.
template: splash
hero:
  tagline: Hệ thống phòng lab GitOps chuẩn chỉnh vận hành Kubernetes rút gọn (k3s) trên VPS Hetzner CX33, tích hợp ArgoCD, mã hoá SOPS + AGE và quản lý DNS qua Cloudflare.
  image:
    file: ../../../assets/logo.svg
  actions:
    - text: Bắt đầu ngay
      link: /lab-hetzner-gitops-k3s/vi/getting-started/overview/
      icon: right-arrow
      variant: primary
    - text: Xem trên GitHub
      link: https://github.com/001123/lab-hetzner-gitops-k3s
      icon: external
      variant: minimal
---

import { Card, CardGrid } from '@astrojs/starlight/components';

## Điểm nhấn kiến trúc hệ thống

<CardGrid stagger>
	<Card title="Hạ tầng dưới dạng mã (IaC)" icon="pencil">
		Tự động hoá bootstrap bằng Ansible playbook: cấu hình UFW firewall, tối ưu hệ điều hành và khởi tạo node k3s.
	</Card>
	<Card title="Folder Sync với ArgoCD" icon="add-document">
		Mô hình App-of-Apps cho hạ tầng platform kết hợp ApplicationSet git-directory tự động đồng bộ mọi ứng dụng người dùng.
	</Card>
	<Card title="Bảo mật bí mật với SOPS + AGE" icon="setting">
		Mã hoá secret đầu-cuối bằng SOPS và AGE. Repo Git public an toàn, KSOPS giải mã trực tiếp trong container repo-server.
	</Card>
	<Card title="Tự động Ingress & TLS" icon="open-book">
		Traefik Ingress controller tích hợp sẵn trong k3s, cert-manager cấp chứng chỉ Let's Encrypt tự động, DNS Cloudflare.
	</Card>
</CardGrid>
