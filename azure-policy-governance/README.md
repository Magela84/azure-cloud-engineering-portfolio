# Governance as Code — Azure Policy

**Domain:** Cloud Governance · **Stack:** Azure Policy (custom + built-in) · Bicep · Terraform (azurerm) · **Effects:** deny + audit at subscription/RG scope

## Objective

Stop *hoping* people configure resources securely and start *enforcing* it. You'll:

1. Write a **custom policy** in Bicep that **denies** storage accounts with public blob access — and prove it blocks a non-compliant deployment.
2. Assign a **built-in policy** ("Allowed locations") with Terraform to restrict a resource group to one region.
3. Check **compliance state** — how you audit an existing estate.

## Why this matters

In Labs 1–2 you hand-configured TLS, HTTPS-only, and no-public-blob every time. Governance-as-code makes those guarantees automatic and org-wide: a Deny policy stops a bad resource before it exists, and Audit policies flag drift on what's already deployed. This is how platform teams enforce security and cost rules at scale.

## Key concepts (quick)

- **Definition** = the rule (if/then). **Assignment** = applying that rule to a scope (management group / subscription / resource group).
- **Effects:** `deny` (block creation), `audit` (allow but flag non-compliant), `deployIfNotExists` / `modify` (auto-remediate — these need a managed identity).
- **Scope inheritance:** a policy assigned higher up (management group) flows down to every subscription and RG beneath it.
- **`enforcementMode`:** `Default` enforces; `DoNotEnforce` is a dry-run that reports what *would* happen without blocking — great for testing new policies.

## Prerequisites

- Labs 1–2 done; Azure Cloud Shell (**bash**); Owner on the subscription (policy definitions/assignments need it).
- Files under `~/lab03` (paste the bootstrap block your trainer provides).

---

## Part A — Custom deny policy with Bicep (≈30 min)

**1. Deploy the policy** (definition + assignment, at subscription scope):
```bash
cd ~/lab03/bicep
az deployment sub create --location eastus --name lab03-policy --template-file policy.bicep
```
Expect `Succeeded` with a `policyDefinitionId` output.

**2. Test that it DENIES a bad resource.** Create a test RG, then try to make a storage account with public blob access on:
```bash
az group create -n azlab03-test-rg -l eastus
az storage account create -n azlab03pub$RANDOM -g azlab03-test-rg -l eastus \
  --allow-blob-public-access true
```
Expected: **`RequestDisallowedByPolicy`** — the create is blocked, and the error names your policy.

> **Propagation note:** a fresh assignment can take a few minutes to become active. If the create *succeeds* the first time, delete that account and retry in ~5 minutes — that delay is itself a known gotcha (and this lab's RCA).

**3. Test that it ALLOWS a compliant resource:**
```bash
az storage account create -n azlab03ok$RANDOM -g azlab03-test-rg -l eastus \
  --allow-blob-public-access false
```
Expected: **succeeds.** Same rule, opposite outcome — the policy discriminates exactly on the condition you wrote.

---

## Part B — Built-in policy with Terraform (≈25 min)

`terraform/main.tf` looks up the built-in **"Allowed locations"** policy by name and assigns it to a new RG, permitting only `eastus`.

**1. Deploy:**
```bash
cd ~/lab03/terraform
terraform init
terraform apply -auto-approve
```

**2. Test the location restriction.** Try to create a resource in a *different* region inside that RG:
```bash
az storage account create -n azlab03loc$RANDOM -g azlab03-tf-rg -l westus \
  --allow-blob-public-access false
```
Expected: **denied** — location `westus` isn't in the allowed list. Repeat with `-l eastus` and it succeeds.

This is the everyday pattern: most governance is **assigning Microsoft's built-in policies** with your parameters, not writing custom ones.

---

## Part C — Compliance state (≈15 min)

Deny stops *new* bad resources; **audit/compliance** tells you about *existing* ones. View compliance:
```bash
# Trigger an on-demand evaluation (normally runs every ~24h)
az policy state trigger-scan --resource-group azlab03-test-rg

# Summarize compliance for the subscription
az policy state summarize --query "value[0].results" -o jsonc
```
Look at compliant vs non-compliant counts. In a real audit, this is the report you'd hand to security.

---

## Part D — Break & Diagnose (RCA) (≈10 min)

**Scenario — "my policy didn't block anything."** If your Part A deny *didn't* fire on the first try:
- *Diagnose:* Was the assignment fully propagated? Check it exists: `az policy assignment list --query "[?name=='azlab03-deny-public-blob-assign']" -o table`. Was `enforcementMode` `Default` (not `DoNotEnforce`)? Was the field path (`allowBlobPublicAccess`) correct?
- *Lesson:* Policy enforcement is eventually-consistent — assignment propagation and evaluation aren't instant. Document how you'd verify a policy is live before trusting it in production.

---

## Part E — Teardown

```bash
# Terraform (RG + its assignment)
cd ~/lab03/terraform && terraform destroy -auto-approve

# Bicep policy — remove assignment, then definition (order matters), then the test RG
az policy assignment delete --name azlab03-deny-public-blob-assign
az policy definition delete --name azlab03-deny-public-blob
az group delete -n azlab03-test-rg --yes --no-wait

# Verify
az policy assignment list --query "[?starts_with(name,'azlab03')].name" -o tsv
az group list --query "[?starts_with(name,'azlab03')].name" -o tsv
```
Both should return empty (RG may linger a minute).

---

## Success criteria ✅

- [ ] Custom deny policy deployed via Bicep at subscription scope
- [ ] Confirmed it blocks a public-blob storage account and allows a compliant one
- [ ] Built-in "Allowed locations" policy assigned via Terraform; confirmed it blocks the wrong region
- [ ] Ran a compliance scan and read the results
- [ ] Understand definition vs assignment, scope inheritance, and deny vs audit
- [ ] Everything torn down (assignments + definition + RGs)

## Reflection questions

1. When would you use `audit` instead of `deny` for a new policy rolling out to production?
2. Why assign policy at a management group rather than each subscription?
3. Which effects require a managed identity, and why?

---

Paste your outputs as you go and I'll document it and prep the next lab.
