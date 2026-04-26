# Azure for SaaS Developers — Terraform Lab

Companion repo for the YouTube series. Each folder is a standalone, runnable snapshot of the infrastructure at that episode — resources accumulate across episodes (everything in EP3 includes EP2 + EP1, etc.).

## Episode index

| Folder | Episode | Adds |
|--------|---------|------|
| `01-resource-group/` | EP 1 — Your First IaC | Resource Group |
| `02-app-service/` | EP 2 — Deploy Next.js | App Service Plan + Linux Web App |
| `03-postgresql/` | EP 3 — PostgreSQL Setup | Flexible Server + Firewall + Database |
| `04-github-actions/` | EP 4 — CI/CD Pipeline | GitHub Actions workflow (no infra change) |
| `05-monitoring/` | EP 5 — Monitor & Alerts | Log Analytics + App Insights + Diagnostic Settings + Alerts |
| `06-custom-domain-ssl/` | EP 6 — Custom Domain & Free SSL | Hostname Binding + Managed Certificate |
| `07-keyvault-managed-identity/` | EP 7 — Key Vault & Managed Identity | Key Vault + RBAC + Secret References |
| `08-remote-state/` | EP 8 — Remote State + Locking | Storage Account backend (bootstrap pattern) |
| `09-multi-environment/` | EP 9 — dev / staging / prod | Workspaces + per-env tfvars |
| `10-cost-guardrails/` | EP 10 — Budgets & Auto-Shutdown | Consumption Budget + Logic App |
| `11-container-apps/` | EP 11 — Azure Container Apps | ACA Environment + Container App (scale-to-zero) |
| `12-multi-region-frontdoor/` | EP 12 — Global SaaS with Front Door | Multi-region web apps + Front Door + Health Probes |

### Arc 2: Scale Up (One → Team → Kubernetes)

| Folder | Episode | Adds |
|--------|---------|------|
| `13-azure-devops/` | EP 13 — Azure DevOps Pipelines | ADO multi-stage pipeline + Service Connection |
| `14-docker/` | EP 14 — Docker for Azure Developers | Multi-stage Dockerfile + .dockerignore |
| `15-container-registry/` | EP 15 — Azure Container Registry | ACR + RBAC roles (AcrPush/AcrPull) |
| `16-container-apps-deep-dive/` | EP 16 — Container Apps Deep Dive | Multi-container (web + worker) + secrets + revisions |
| `17-aks-first-cluster/` | EP 17 — Your First AKS Cluster | AKS + node pool + autoscaling + Container Insights |
| `18-helm-charts/` | EP 18 — Helm Charts for SaaS | Chart structure + Deployment + Service templates |
| `19-aks-ingress-cert-manager/` | EP 19 — Ingress + cert-manager | NGINX Ingress + Let's Encrypt auto-TLS |
| `20-hpa-keda/` | EP 20 — HPA + KEDA Autoscaling | CPU/memory HPA + event-driven KEDA (scale-to-zero) |
| `21-aks-keyvault-csi/` | EP 21 — Key Vault CSI Driver | Mount KV secrets as files inside pods |
| `22-blue-green-canary/` | EP 22 — Blue/Green + Canary Deploys | Zero-downtime release patterns |
| `23-aks-monitoring/` | EP 23 — Prometheus + Grafana | kube-prometheus-stack (full observability) |
| `24-production-aks/` | EP 24 — Production AKS (Finale) | Azure CNI + Calico + multi-AZ + resource quotas |

## Standards applied across the lab

Every `.tf` follows these rules so the patterns transfer directly to production:

- **Region: `westus2`.** Fresh Azure subscriptions typically have **0 quota for App Service VMs in `eastus`** — `westus2` and `centralus` work out of the box.
- **Provider pinning** — `~> 4.0` of the `azurerm` provider, with `required_version >= 1.5` for Terraform.
- **Standard tag set** — `Environment`, `Workload`, `Owner`, `CostCenter`, `ManagedBy`, `Repository`. Applied via `local.common_tags` to every resource.
- **HTTPS-only + TLS 1.2 minimum** on all public endpoints. FTPS disabled. Basic-auth deploy paths disabled.
- **Health checks** on every web app (`/`).
- **System-Assigned Managed Identity** on the web app from EP 2 onward (used by Key Vault in EP 7).
- **Diagnostic settings** stream platform logs and metrics to Log Analytics from EP 5 onward.
- **Postgres TLS enforced** via `require_secure_transport = ON`.
- **Sensitive variables** declared `sensitive = true` and never echoed.
- **Lifecycle guards** (`ignore_changes`) on values Azure mutates server-side (e.g., Postgres availability zones).

## Prerequisites

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install azure-cli postgresql gh
az login
gh auth login
```

Verify quota in your target region BEFORE recording:

```bash
az vm list-usage --location westus2 -o table | grep -i 'basic\|standard'
```

## Quick start (any episode)

```bash
cd 02-app-service/infra      # or any episode
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Cleanup

```bash
# From the LAST episode folder you applied (resources accumulate):
terraform destroy -auto-approve
```

## Estimated monthly cost (if left running)

| Layer | Approx cost |
|---|---|
| App Service B1 | ~$13 |
| PostgreSQL B1ms | ~$12 |
| Log Analytics | ~$2–5 |
| Key Vault | ~$0.03 |
| Storage Account (state) | ~$0.50 |
| Front Door Standard (EP 12) | ~$35 |

**Destroy within the same day = pennies.** Forget for a month = ~$30 baseline, ~$80 if EP 12 is up.
