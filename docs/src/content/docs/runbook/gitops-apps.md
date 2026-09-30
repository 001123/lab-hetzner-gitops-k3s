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
  cert-manager.io/cluster-issuer: letsencrypt-production
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

---

## 5. Monitoring Stack (VictoriaMetrics + Grafana)

Monitoring lives in the **infra** tier (`cluster/infra/`) — deployed as one
Application named `infra`, ordered by sync-waves: `victoria-metrics` (0) then
`grafana` (1):

| Component | Chart (pinned) | What it runs |
|---|---|---|
| `victoria-metrics` | `victoria-metrics-k8s-stack` `0.95.0` (VictoriaMetrics `v1.153.0`) | VM operator + VMSingle (storage/query, 20Gi PVC, 1-month retention) + VMAgent + kube-state-metrics + node-exporter; scrapes kubelet/cAdvisor and the k3s control-plane components |
| `grafana` | `grafana` `13.2.7` (Grafana `13.2.3`) | Grafana UI at `https://grafana.timi.io.vn`, datasource = VMSingle, dashboards via sidecar |

Operational notes:

* Charts are pinned under `helmCharts:` in each component's `kustomization.yaml` and
  inflated with `--enable-helm`. Upgrade = bump `version:`, then `make validate`
  and push. The newest Grafana charts live in
  `https://grafana-community.github.io/helm-charts` (chart version tracks the app
  version); the old `grafana.github.io/helm-charts` repo only ships Grafana 12.x.
* `includeCrds: true` on the victoria-metrics chart is required — kustomize's helm
  inflation drops the chart `crds/` directory without it.
* Grafana admin credentials: `sops -d cluster/infra/grafana/secret.sops.yaml`.
* Dashboards are created as ConfigMaps by the k8s-stack sync-job and picked up by
  the Grafana sidecar; the datasource must keep `uid: VictoriaMetrics`.
* VM operator webhook certificates are issued by cert-manager
  (`admissionWebhooks.certManager.enabled: true`) to avoid random self-signed
  certs causing permanent OutOfSync diffs.

Validation:

```bash
kubectl -n victoria-metrics get pods
kubectl -n victoria-metrics port-forward svc/vmsingle-vm 8428
curl 'localhost:8428/api/v1/query?query=up'
kubectl -n grafana get pods,ingress
```
