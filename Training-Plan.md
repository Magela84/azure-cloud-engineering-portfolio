# Azure Training Plan — Advanced Track

A progression designed for an advanced engineer sharpening across all eight skill areas. Each lab is scoped to a single 1–2 hour session, builds real infrastructure, and reinforces **Troubleshooting & RCA** by including a "break it and fix it" segment.

The order is deliberate: IaC first (so every later lab can be deployed reproducibly), then admin/automation fundamentals, then the specialist tracks, finishing with architecture — where you'll design a full solution using everything prior.

## Lab sequence

### Module 1 — Infrastructure as Code
- **Lab 01 · IaC foundations with Bicep & Terraform** *(current)* — Deploy a secure network + storage + Key Vault stack twice, once in each tool. Learn modules, parameters, `what-if`/`plan`, idempotency, and state. RCA: fix a failed deployment.
- **Lab 02 · Modules, reuse & remote state** — Author reusable modules; put Terraform state in an Azure Storage backend with locking; Bicep with a private module registry.
- **Lab 03 · Policy & governance as code** — Azure Policy, management groups, and deny/audit rules deployed via IaC.

### Module 2 — Administration & Automation
- **Lab 04 · Azure Administration deep-dive** — RBAC, resource locks, tags, storage lifecycle, networking (VNet peering, NSGs, Private Endpoints).
- **Lab 05 · PowerShell & Azure CLI automation** — Scripted provisioning, bulk operations, idempotent scripts, and an Automation Account runbook.

### Module 3 — Security & Identity
- **Lab 06 · Entra ID & identity** — App registrations, service principals, managed identities, Conditional Access concepts.
- **Lab 07 · Secrets, encryption & network security** — Key Vault, RBAC vs access policies, Private Endpoints, NSG/firewall hardening.

### Module 4 — Operations
- **Lab 08 · Monitoring & Observability** — Log Analytics, KQL, metric alerts, Application Insights, workbooks and dashboards.
- **Lab 09 · DevOps & CI/CD** — GitHub Actions (or Azure DevOps) pipeline that lints, `what-if`s, and deploys your Lab 01 IaC with an approval gate.

### Module 5 — Cost & Architecture
- **Lab 10 · FinOps & Cost Optimization** — Cost Management, budgets/alerts, right-sizing, reserved-instance analysis, tagging for chargeback.
- **Lab 11 · Cloud Architecture capstone** — Design and deploy a resilient, secure, cost-aware multi-tier solution end-to-end, documented as an architecture decision record (ADR).

## Troubleshooting & RCA (continuous)

Every lab includes a **"Break & Diagnose"** section: I introduce a realistic misconfiguration (wrong RBAC scope, drifted state, NSG blocking traffic, a bad parameter) and you diagnose root cause using logs, `az` queries, and IaC tooling — then document the RCA.

## Working agreement

- You run all commands in **your** subscription — I never touch your Azure resources directly.
- I write the labs, review your output/errors when you paste them, explain the *why*, and adjust difficulty.
- Every lab is documented in its `lab-notes.md`; the running log lives in `Progress-Log.md`.
- Ask me to go deeper, add a challenge, or slow down at any point.
