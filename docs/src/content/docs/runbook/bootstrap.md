---
title: Cluster & ArgoCD Bootstrap Runbook
description: Step-by-step operational runbook to provision k3s, ArgoCD, KSOPS, and TLS certificates using Ansible.
---

## 1. Pre-Flight Verification

Before triggering the Ansible bootstrap playbook, ensure the following requirements are fulfilled:

1. SSH connectivity to Hetzner CX33:
   ```bash
   ssh hetzner-cx33-nbg "uname -a"
   ```
2. The AGE private key exists locally at `~/.config/sops/age/keys.txt`:
   ```bash
   test -f ~/.config/sops/age/keys.txt && echo "Key exists"
   ```
3. Encrypt any plaintext bootstrap variables if updated:
   ```bash
   make sops-encrypt
   ```

---

## 2. Executing the Bootstrap Pipeline

Run the pre-flight syntax and schema validation, then execute the full idempotency-safe Ansible playbook:

```bash
# 1. Validate Kustomize manifests and Ansible playbook syntax
make validate

# 2. Run the master bootstrap playbook
make bootstrap

# 3. Verify node readiness from your local machine
make nodes
```

Expected node output:
```text
NAME                            STATUS   ROLES                  AGE   VERSION
docker-ce-ubuntu-8gb-nbg1-1     Ready    control-plane,master   2m    v1.37.0+k3s1
```

---

## 3. Kubeconfig Management

The Ansible playbook fetches the cluster kubeconfig to a dedicated local file: `~/.kube/hetzner-cx33-nbg.yaml` rather than overwriting your default configuration.

To interact with the cluster:

```bash
# Option A: Export environment variable for the current terminal session
export KUBECONFIG=~/.kube/hetzner-cx33-nbg.yaml

# Option B: Backup existing ~/.kube/config and install this cluster as default
make kubeconfig
```

---

## 4. Validating the ArgoCD Platform

After `make bootstrap` finishes, verify that all ArgoCD pods are running and KSOPS is ready:

```bash
kubectl get pods -n argocd
```

Expected output:
```text
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          3m
argocd-applicationset-controller-...                1/1     Running   0          3m
argocd-dex-server-...                               1/1     Running   0          3m
argocd-redis-...                                    1/1     Running   0          3m
argocd-repo-server-...                              1/1     Running   0          3m
argocd-server-...                                   1/1     Running   0          3m
```

### Ingress & TLS Verification

Query the public ArgoCD endpoint over HTTPS:

```bash
curl -sI https://argocd.timi.io.vn
```

Expected response headers:
```http
HTTP/2 200
server: Cowboy / Traefik
strict-transport-security: max-age=63072000; includeSubDomains; preload
```

### Initial Administrator Login

* **URL**: `https://argocd.timi.io.vn`
* **Username**: `admin`
* **Password**: Retrieved from the encrypted secret in `ansible/inventory/group_vars/all.sops.yml` (`argocd_admin_password`).
