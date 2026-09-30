---
title: Project Overview & Objectives
description: Background, server infrastructure, domain configuration, and pinned versions for the Hetzner k3s GitOps lab.
---

## 1. Project Background & Context

This project establishes a resilient, production-ready GitOps platform on a single Hetzner Cloud virtual server, combining lightweight Kubernetes (**k3s**) and **ArgoCD** with zero-trust secret management (**SOPS + AGE**).

### Infrastructure Specifications

* **Host Provider**: Hetzner Cloud (Datacenter: NBG1 - Nuremberg, Germany)
* **Instance Type**: CX33 (2 vCPU / 8 GB RAM / 80 GB NVMe SSD)
* **Operating System**: Ubuntu 24.04.1 LTS
* **SSH Access**: Alias `hetzner-cx33-nbg` (User: `root`, IP: `188.245.30.55`)
* **Host Runtime**: Docker CE 27.5.1 is pre-installed on the host image. k3s runs its own isolated `containerd` runtime without conflict.

### Domain & DNS Routing

* **Apex Domain**: `timi.io.vn` (Managed via Cloudflare, Zone ID `61a104b48738150008058d14de5e5110`)
* **Core Subdomains**:
  * `argocd.timi.io.vn` → ArgoCD Web UI & API
  * `demo-nginx.timi.io.vn` → Sample workload to validate the end-to-end GitOps pipeline
* **DNS Management**: Managed locally via the Cloudflare CLI `cf` (`v1.0.0-beta.6`). Initial setup uses Grey Cloud (DNS-only) to avoid proxy anomalies during HTTP-01 ACME challenges.

---

## 2. Pinned Technology Stack

To ensure reproducibility and eliminate version drift, all major components are pinned to verified releases:

| Component | Pinned Version | Scope & Notes |
|---|---|---|
| **k3s** | `v1.37.0+k3s1` | Installed via official script with `INSTALL_K3S_VERSION` |
| **Argo CD** | `v3.5.3` | Installed via official Helm chart `argo-cd` **10.9.4** |
| **cert-manager** | `v1.17.1` | Manages automated Let's Encrypt certificates |
| **SOPS** | `v3.13.3` | Local secret encryption & remote decryption |
| **AGE** | `v1.3.2` | Key generator & identity provider for SOPS |
| **KSOPS** | `v4.5.1` | Distroless plugin container for `argocd-repo-server` |
| **Ansible** | `14.4.0` (core 2.21.4) | Local bootstrap orchestrator running on macOS |
| **kubectl** | `v1.37.1` | Local CLI matching the k3s cluster minor version |
| **Helm** | `v4.3.0` | Local Helm client |
| **Kustomize** | `v5.8.1` | Manifest templating and generator engine |

---

## 3. Core Architectural Decisions

1. **Monorepo Layout**: Ansible playbooks, Kubernetes platform manifests, and user application definitions all reside in a single repository (`001123/lab-hetzner-gitops-k3s`).
2. **Strict Separation of Concerns**:
   * **Ansible** is executed once during initial server bootstrapping (operating system hardening, firewall rules, k3s installation, and ArgoCD initialization).
   * **ArgoCD** assumes 100% declarative ownership over the cluster state following bootstrap. No manual `kubectl apply` commands are permitted in steady state.
3. **Decentralized Secrets**: Plaintext secrets are never committed. Secrets are encrypted using SOPS and an AGE public key locally, stored encrypted in Git, and decrypted transparently on-demand in-cluster by KSOPS.
4. **App-of-Apps & ApplicationSets**:
   * Platform infrastructure (Traefik, cert-manager) is orchestrated via the **App-of-Apps** pattern.
   * User applications in `cluster/apps/*` are dynamically detected and synchronized using ArgoCD **ApplicationSets** with Git Directory generators.
