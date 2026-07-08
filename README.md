# Azure Cloud Engineering Portfolio

Hands-on Azure infrastructure projects built with Infrastructure as Code (Bicep & Terraform), covering the full engineering stack: deployment, team-grade IaC, governance, identity, and network security. Each project was deployed to a live Azure subscription, verified, documented, and torn down.

**Author:** Magela · **Tools:** Azure CLI · Bicep · Terraform · Azure Policy · Entra ID / RBAC · Azure AI Services · Log Analytics · GitHub Actions · Git

---

## Projects

| Project | Focus | What it demonstrates |
|---------|-------|----------------------|
| [azure-iac-secure-baseline](./azure-iac-secure-baseline) | Infrastructure as Code | Same secure stack (VNet + NSG + hardened storage + RBAC Key Vault) deployed in **both Bicep and Terraform**; preview-before-apply, idempotency, and root-cause analysis of provider drift. |
| [azure-terraform-remote-state](./azure-terraform-remote-state) | Team-grade Terraform | **Remote state** in Azure Storage with locking; a **reusable module** instantiated multiple times; publishing/consuming a **Bicep module** from a private registry (ACR). |
| [azure-policy-governance](./azure-policy-governance) | Governance as Code | A **custom deny policy** (blocks public-blob storage) and a **built-in policy** ("Allowed locations") — enforcing standards automatically across a subscription. |
| [azure-managed-identity-rbac](./azure-managed-identity-rbac) | Security & Identity | **Managed identity**, **data-plane vs control-plane RBAC**, Key Vault secrets, and storage with account keys disabled (Azure AD-only access). |
| [azure-private-endpoints](./azure-private-endpoints) | Network Security | Locking storage & Key Vault to **private-only networking** with **Private Endpoints and Private DNS**, including the DNS resolution mechanics. |
| [azure-monitoring-observability](./azure-monitoring-observability) | Monitoring & Observability | **Log Analytics**, near-real-time **metrics**, the **Activity Log** audit trail, **KQL** queries, and **metric alerts** — the toolset behind real incident troubleshooting. |
| [azure-devops-cicd](./azure-devops-cicd) | DevOps / CI-CD | A **GitHub Actions** pipeline that automatically compiles Bicep and validates Terraform on every push, plus a reference **deploy-with-approval** workflow. |
| [azure-finops-cost](./azure-finops-cost) | FinOps / Cost Optimization | A **budget with email alerts**, **cost tags** for chargeback, a real **cost review** (finding idle resources), tag-enforcement policy, and the optimization levers. |
| [azure-administration](./azure-administration) | Azure Administration | **Resource locks** (blocking deletion), **tags at scale**, **storage lifecycle** automation, and **Azure Resource Graph** inventory — the day-to-day management skills. |
| [azure-powershell-cli-automation](./azure-powershell-cli-automation) | PowerShell, CLI & Automation | Azure **CLI vs PowerShell** side by side, a reusable **cloud-report** automation script, and **Azure Automation** for cloud-native scheduled runbooks. |
| [azure-ai-secure-deployment](./azure-ai-secure-deployment) | AI on Azure (secure) | An **Azure AI Services** account deployed via Bicep with **API keys disabled** (Azure AD-only), a **managed identity**, **Cognitive Services User** RBAC, and logs/metrics to **Log Analytics** — running AI securely and cost-consciously. |

> A reusable, production-leaning **secure-baseline starter template** is maintained in its own repository.

---

## Skills demonstrated

- **Infrastructure as Code** — Bicep and Terraform: modules, parameters, `what-if`/`plan`, idempotency, remote state + locking, module registries.
- **Security & Identity** — RBAC (control-plane vs data-plane), managed identities, Key Vault, disabling shared-key access, least privilege.
- **Network Security** — Private Endpoints, Private DNS, disabling public network access.
- **Governance** — Azure Policy as code (custom + built-in, deny vs audit, scope inheritance).
- **AI on Azure (secure)** — deploying AI Services as code with keys disabled, managed identity, data-plane RBAC, monitoring, and token-cost awareness.
- **Troubleshooting / RCA** — diagnosing issues against live resources and resolving them methodically (documented in each project's notes).

## How each project is organized

Each folder contains the infrastructure code (`bicep/` and/or `terraform/`), a `README.md` walking through the objective and steps, and `lab-notes.md` documenting the real deployment run, including any issues diagnosed and fixed.

## Running a project

Prerequisites: an Azure subscription, Azure CLI, and Terraform. From a project folder, deploy with the commands in its `README.md` (always preview with `what-if` / `plan` first), and tear down when finished. Templates are parameterized — change the name prefix, region, and environment to fit your own subscription.
