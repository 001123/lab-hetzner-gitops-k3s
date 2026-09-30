---
title: GitOps Workloads & Application Delivery
description: Deploying the root application, onboarding user applications via ApplicationSets, and validating self-healing.
---

## 1. Initializing GitOps Root

Once the cluster is bootstrapped, declarative GitOps begins by applying the entrypoint root application:

```bash
kubectl apply -k cluster/bootstrap/root-app
```

The `root-app` points to `cluster/bootstrap/children/`, which immediately yields:
1. `platform`: Deploys cert-manager and ClusterIssuers into the `cert-manager` namespace.
2. `apps`: An ArgoCD ApplicationSet tracking all subdirectories in `cluster/apps/*`.

---

## 2. Onboarding New Applications

Because the ApplicationSet utilizes a Git directory generator (`path: cluster/apps/*`), onboarding an application requires zero changes to ArgoCD or cluster configurations.

### Standard Directory Skeleton

To add an application named `my-service`:

```text
cluster/apps/my-service/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
├── ingress.yaml
└── secret.sops.yaml          # Optional: encrypted runtime secrets
```

### Reference Example: `demo-nginx`

The repository includes a reference implementation under `cluster/apps/demo-nginx/`:
* Serves a customized `index.html` via a ConfigMap.
* Encrypted API keys in `secret.sops.yaml`.
* Ingress pointing to `demo-nginx.timi.io.vn` with automated TLS annotation:
  ```yaml
  cert-manager.io/cluster-issuer: letsencrypt-prod
  ```

Commit and push the directory:
```bash
git add cluster/apps/my-service
git commit -m "feat: onboard my-service via GitOps"
git push origin main
```

Within 3 minutes (or immediately after triggering manual refresh in the UI), ArgoCD detects the new directory, provisions the Application, and rolls out the workloads.

---

## 3. Validating Self-Healing & Drift Detection

ArgoCD is configured with both automated synchronization and self-healing (`selfHeal: true`).

### Test 1: Manual Resource Deletion
Delete a running application pod:
```bash
kubectl delete pod -l app=demo-nginx -n demo-nginx
```
**Observation**: The ReplicaSet immediately replaces the pod.

### Test 2: Out-of-Band Configuration Drift
Attempt to manually tamper with the deployment replicas using `kubectl`:
```bash
kubectl scale deployment demo-nginx --replicas=5 -n demo-nginx
```
**Observation**: ArgoCD detects the discrepancy between Git (`replicas: 1`) and the live cluster state, instantly reverting the cluster back to 1 replica.

---

## 4. Application Rollback Strategy

In a GitOps paradigm, rollbacks are performed via Git history rather than imperative commands:

```bash
# Revert the faulty commit in Git
git revert <commit-sha>
git push origin main
```

ArgoCD syncs the previous valid commit state cleanly, leaving an immutable audit trail.
