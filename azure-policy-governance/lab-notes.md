# Lab 03 — Notes & Documentation

> Trainer-maintained log. Filled in as you paste outputs.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. Governance-as-code lab following the IaC track.

## Part A — Custom deny policy (Bicep)
- `az deployment sub create` → **Succeeded**. Created policy definition `azlab03-deny-public-blob` + subscription-scoped assignment `azlab03-deny-public-blob-assign`.
- Deny test (public blob = true): **BLOCKED** with `RequestDisallowedByPolicy`. Error's `evaluationDetails` showed both conditions True (type = storage account, allowBlobPublicAccess = true). Enforced immediately — no propagation delay this run.
- Allow test (public blob = false): **Succeeded** (`azlab03ok4212`). Policy is precise — blocks only violations.
- Insight: the compliant account still had `minimumTlsVersion: TLS1_0` — it passed because the policy ONLY checks public blob access. Lesson: a policy enforces exactly what you write. Production bundles many rules into an *initiative* (policy set) to cover TLS, encryption, locations, tags together.

## Part B — Built-in policy (Terraform)
- Assigned the built-in "Allowed locations" policy (GUID `e56962a6-...` resolved automatically via `data "azurerm_policy_definition"` by display name — no hardcoded GUID) to RG `azlab03-tf-rg`, allowing only `eastus`. Assignment took ~1m40s to create.
- Location deny test (westus): **BLOCKED** — `RequestDisallowedByPolicy`, eval detail `location NotIn [eastus]`.
- Allow test (eastus): **Succeeded** (`azlab03east10625`).
- Pattern learned: most governance is *assigning Microsoft's built-in policies* with your parameters, not writing custom ones.

## Part C — Compliance
- `az policy state trigger-scan` ran; immediate `summarize` returned empty.

## Part D — RCA — compliance reporting is asynchronous
- **Symptom:** compliance summary was empty right after triggering a scan.
- **Root cause:** policy *reporting* is eventually-consistent — a triggered scan queues an evaluation that takes minutes to populate; it isn't instant.
- **Key distinction:** **deny enforcement is SYNCHRONOUS** (blocks at create time, as seen in Parts A & B), while **compliance/audit data is ASYNCHRONOUS** (populates on a delay). Trust deny to block immediately; don't expect a compliance dashboard to refresh instantly.
- **Fix/lesson:** wait a few minutes (or for the ~24h default cycle) before reading compliance results; use deny for hard guarantees and audit for visibility.

## Part E — Teardown + bonus RCA
- `terraform destroy` removed the policy assignment but **failed to delete `azlab03-tf-rg`**: error "the Resource Group still contains Resources" — the storage account `azlab03east10625` created manually with `az` during testing.
- **Root cause:** Terraform manages only what's in its state. The `az`-created account is out-of-band, and the azurerm provider's `prevent_deletion_if_contains_resources` safety default blocks deleting an RG with unmanaged resources.
- **Fix:** `az group delete -n azlab03-tf-rg --yes` (removes the RG + stray account directly). Alternative: set `prevent_deletion_if_contains_resources = false` in the provider `features` block.
- **Lesson:** mixing manual (`az`) changes with Terraform-managed infra creates state boundaries that can block operations — same state principle as Lab 02, as a guardrail.
- Bicep cleanup: deleted assignment, then definition (order matters), then `azlab03-test-rg`.

## Reflection answers
1.
2.
3.

## Teardown confirmation
- [x] Policy assignment deleted (assignment list returned empty)
- [x] Policy definition deleted
- [x] Test RGs deletion issued (background); RGs clear shortly

## Lab 03 — Summary & outcome ✅
Enforced security/governance rules automatically instead of configuring by hand. Wrote a custom Bicep policy that DENIES storage accounts with public blob access (proved it blocks a bad account and allows a compliant one), assigned Microsoft's built-in "Allowed locations" policy via Terraform (proved it blocks the wrong region), and examined compliance state.

**Skills:** custom policy definitions + assignments (Bicep, subscription scope), consuming built-in policies by display name (Terraform), deny vs audit effects, scope inheritance, compliance scanning, and three RCAs.

**Key takeaways**
- Definition = the rule; assignment = applying it to a scope; scope flows downward.
- A policy enforces exactly what you write — bundle rules into an initiative for full coverage.
- Deny enforcement is synchronous (blocks at create); compliance reporting is asynchronous.
- Most governance = assigning built-in policies with parameters, not writing custom ones.
- Terraform manages only what's in its state; out-of-band `az` resources can block RG deletion.
- Prefer `deny` for hard guarantees, `audit` for visibility / phased rollout.
