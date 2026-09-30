---
title: Common Issues & Gotchas
description: Troubleshooting guide covering KSOPS distroless crashes, ACME challenge failures, sync wave races, and firewall safeguards.
---

## 1. KSOPS v4.5.1 Distroless InitContainer Failure

### Symptom
The `argocd-repo-server` pod is stuck in `Init:CrashLoopBackOff` or reports:
```text
container_linux.go: starting container process caused: exec: "sh": executable file not found in $PATH
```

### Cause
Starting with KSOPS `v4.4`, upstream images changed to **Google Distroless**. The legacy initContainer pattern of launching a shell (`sh -c "cp /usr/local/bin/ksops /custom-tools/"`) fails because no shell binary exists inside the image.

### Solution
Configure the initContainer to invoke the built-in installer directly without a shell:
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
The `--with-kustomize` argument is mandatory because ArgoCD ships with its own standalone Kustomize binary.

---

## 2. Let's Encrypt Rate Limits & HTTP-01 Challenges

### Symptom
Certificates remain in `Issuing` or ACME challenge reports authorization timeouts:
```text
Waiting for HTTP-01 challenge propagation
```

### Troubleshooting Steps
1. **Cloudflare Proxying**:
   Ensure DNS records for `argocd.timi.io.vn` and `demo-nginx.timi.io.vn` are initially set to **Grey Cloud (DNS-only)**. Once certificates are successfully issued, Cloudflare proxying (Orange Cloud) can be enabled with SSL mode set to **Full (strict)**.
2. **ACME Rate Limits**:
   During active testing, point the ClusterIssuer to the Let's Encrypt **Staging** environment (`https://acme-staging-v02.api.letsencrypt.org/directory`) to avoid production rate limits (5 certificates per week for duplicate sets).

---

## 3. Transient `ClusterIssuer` Not Found Error

### Symptom
ArgoCD shows synchronization degraded with error:
```text
the server could not find the requested resource (post clusterissuers.cert-manager.io)
```

### Cause & Solution
Cert-manager CustomResourceDefinitions (CRDs) were not fully registered in the Kubernetes API when the `ClusterIssuer` manifest was applied.
* Use ArgoCD sync waves: assign `argocd.argoproj.io/sync-wave: "-1"` to the cert-manager deployment and `argocd.argoproj.io/sync-wave: "0"` to the `ClusterIssuer`.
* Because ArgoCD self-heals, the controller will automatically converge and succeed on the next reconciliation cycle.

---

## 4. SSH & Firewall Safeguards

### Symptom
Inability to connect via SSH after executing the Ansible `common` role.

### Root Cause
UFW firewall enabled without allowing port 22 or specific inbound developer IPs.

### Emergency Recovery
1. Log into the [Hetzner Cloud Console](https://console.hetzner.cloud/).
2. Open the **VNC Web Console** for `hetzner-cx33-nbg`.
3. Check and restore firewall access:
   ```bash
   sudo ufw status verbose
   sudo ufw allow 22/tcp
   sudo ufw reload
   ```

---

## 5. Single-Node Resource Monitoring

The CX33 server provides 2 vCPU and 8GB of RAM. The baseline control plane and GitOps components consume approximately 1.5GB to 2.0GB:

```bash
# Monitor node resource pressure
kubectl top node

# Monitor memory distribution across all namespaces
kubectl top pods -A --sort-by=memory
```
