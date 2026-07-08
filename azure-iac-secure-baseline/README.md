# Secure Baseline Infrastructure — Bicep & Terraform

**Domain:** Infrastructure as Code · **Stack:** Azure CLI · Bicep · Terraform (azurerm) · **Scope:** VNet + NSG + hardened Storage + RBAC Key Vault

## Objective

Deploy the same secure baseline stack **twice** — once with Bicep, once with Terraform — so you internalize how each tool models identical infrastructure. You'll practice modules, parameters/variables, preview-before-apply (`what-if` / `plan`), idempotency, outputs, and clean teardown. Then you'll deliberately break a deployment and perform a root-cause analysis.

**What you'll deploy:**
- A resource group
- A VNet with a `workload` subnet and an NSG (explicit deny-all-inbound)
- A hardened Storage Account (TLS 1.2, HTTPS-only, no public blob access)
- A Key Vault using the **RBAC authorization** model

## Prerequisites

- `az login` done, correct subscription selected (`az account show`)
- `az bicep version`, `terraform version` both work
- **Permissions:** you need Owner or Contributor + User Access Administrator on the subscription (Key Vault RBAC + subscription-scope deployment need this)

> **Region:** defaults to `eastus`. Change via parameters/variables if you prefer another region.

---

## Part A — Bicep (≈40 min)

All commands run from the `bicep/` folder.

**1. Lint & compile** — catch errors before touching Azure:
```bash
az bicep build --file main.bicep
```
This transpiles to ARM JSON and surfaces warnings. Fix anything red.

**2. Preview with what-if** — the single most important habit in IaC. It shows exactly what will change:
```bash
az deployment sub what-if \
  --location eastus \
  --template-file main.bicep \
  --parameters @main.parameters.json
```
Read the output. Everything should be `+ Create`. Note how many resources.

**3. Deploy:**
```bash
az deployment sub create \
  --location eastus \
  --name lab01-bicep \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

**4. Prove idempotency** — re-run the exact same `create` command. A correct IaC template produces **no changes** on the second run. Confirm the resource count is unchanged and what-if would show `= Nothing`.

**5. Inspect outputs:**
```bash
az deployment sub show --name lab01-bicep \
  --query properties.outputs -o jsonc
```
Record the storage account name and Key Vault URI in your notes.

**6. Validate in Azure:**
```bash
RG=$(az deployment sub show --name lab01-bicep --query properties.outputs.resourceGroupName.value -o tsv)
az resource list -g "$RG" -o table
# Confirm the storage security posture:
az storage account show -g "$RG" -n <storageName> \
  --query "{tls:minimumTlsVersion, https:supportsHttpsTrafficOnly, publicBlob:allowBlobPublicAccess}" -o jsonc
```
Expected: `TLS1_2`, `true`, `false`.

---

## Part B — Terraform (≈40 min)

Run from the `terraform/` folder. **Important:** change `name_prefix` (e.g. to `azlab01b`) via a `-var` so Terraform's globally-unique storage/KV names don't collide with the Bicep deployment.

**1. Init & format check:**
```bash
terraform init
terraform fmt -check
terraform validate
```

**2. Plan** (the Terraform equivalent of what-if):
```bash
terraform plan -var="name_prefix=azlab01b" -out=tfplan
```
Compare this output mentally to the Bicep what-if. Same resources, different mental model (Terraform tracks **state**; Bicep is stateless and reconciles against Azure directly).

**3. Apply:**
```bash
terraform apply tfplan
```

**4. Prove idempotency:**
```bash
terraform plan -var="name_prefix=azlab01b"
```
Expected: `No changes. Your infrastructure matches the configuration.`

**5. Inspect state & outputs:**
```bash
terraform output
terraform state list
```

---

## Part C — Break & Diagnose (RCA) (≈20 min)

Pick **one** (or both) and document your root-cause analysis in `lab-notes.md`.

**Scenario 1 — Storage name collision.** In `main.parameters.json`, hardcode a `namePrefix` you know is short and generic. Redeploy Bicep. You'll likely hit a `StorageAccountAlreadyTaken` error (names are globally unique).
- *Diagnose:* Which resource failed? Read the exact error code. Why does storage naming behave differently from, say, the NSG?
- *Fix:* Explain how the `uniqueString()` suffix in `main.bicep` is designed to prevent this, and restore it.

**Scenario 2 — Drift detection.** After the Terraform apply, manually add a tag to the storage account in the Azure Portal (e.g. `owner=me`). Then run `terraform plan` again.
- *Diagnose:* Terraform detects drift. What does it propose and why? What would `az` (Bicep, stateless) do differently on its next what-if?
- *Fix:* Decide whether to `terraform apply` (revert the manual change) or import the change into config. Explain the FinOps/governance reason manual portal edits are dangerous.

---

## Part D — Teardown (do not skip)

```bash
# Terraform
cd terraform && terraform destroy -var="name_prefix=azlab01b" -auto-approve

# Bicep (delete the whole RG)
az group delete --name <bicep-rg-name> --yes --no-wait

# Purge soft-deleted Key Vaults so names free up and you're not billed:
az keyvault list-deleted --query "[].name" -o tsv
az keyvault purge --name <kv-name>
```

Then run `az resource list -o table` and confirm nothing from this lab remains.

---

## Success criteria ✅

- [ ] Bicep stack deployed; second run showed **no changes** (idempotent)
- [ ] Terraform stack deployed with a different prefix; `plan` showed no changes on re-run
- [ ] You can articulate **two concrete differences** between how Bicep and Terraform manage state
- [ ] Storage posture verified as TLS1_2 / HTTPS-only / no public blob
- [ ] At least one RCA scenario completed and written up
- [ ] Everything torn down; Key Vault purged; `lab-notes.md` filled in

## Reflection questions (answer in your notes)

1. Bicep is stateless (reconciles against live Azure); Terraform keeps a state file. Give one operational risk of **each** approach.
2. Where should Terraform state live for a team, and why not local? (Preview of Lab 02.)
3. The storage module sets `allowSharedKeyAccess: true` and `defaultAction: 'Allow'`. What's the more secure posture, and what would you need to add to get there without breaking access? (Preview of Labs 06–07.)

---

When you're done, paste me your outputs, any errors, and your answers — I'll review them, correct misconceptions, and set up Lab 02. Stuck partway? Paste the error and I'll help you diagnose it live.
