---
title: Hetzner k3s GitOps Documentation
description: Complete production-ready guide for single-node k3s, ArgoCD GitOps, Traefik, cert-manager, and SOPS+AGE on Hetzner Cloud.
template: splash
hero:
  tagline: Production-ready GitOps lab running lightweight Kubernetes (k3s) on Hetzner Cloud CX33 with ArgoCD, SOPS + AGE secrets encryption, and Cloudflare DNS.
  image:
    file: ../../assets/logo.svg
  actions:
    - text: Getting Started
      link: /lab-hetzner-gitops-k3s/getting-started/overview/
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/001123/lab-hetzner-gitops-k3s
      icon: external
      variant: minimal
---

import { Card, CardGrid } from '@astrojs/starlight/components';

## Core Architecture Highlights

<CardGrid stagger>
	<Card title="Infrastructure as Code" icon="pencil">
		Automated bootstrapping with Ansible playbooks for UFW firewall, system hardening, and k3s node initialization.
	</Card>
	<Card title="ArgoCD Folder Sync" icon="add-document">
		App-of-Apps pattern for platform infrastructure coupled with git-directory ApplicationSets for automated user application delivery.
	</Card>
	<Card title="Zero-Trust Secrets with SOPS" icon="setting">
		Strong end-to-end secret encryption using SOPS and AGE. Public Git repository with in-cluster KSOPS decryption via ArgoCD repo-server.
	</Card>
	<Card title="Automated Ingress & TLS" icon="open-book">
		Traefik Ingress controller bundled with k3s, automated Let's Encrypt certificates managed by cert-manager, and Cloudflare DNS.
	</Card>
</CardGrid>
