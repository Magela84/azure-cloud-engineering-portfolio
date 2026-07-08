# Team-Grade Terraform — Remote State & Reusable Modules

**Domain:** Infrastructure as Code (production practices) · **Stack:** Terraform (azurerm) · Azure Storage backend · Bicep module registry (ACR)

## Objective

Take Lab 01's working-but-basic IaC and make it **team-ready**:

1. **Terraform remote state** in an Azure Storage backend, with automatic **state locking** — so multiple engineers can't corrupt state by running at the same time.
2. **Reusable Terraform module** — write a hardened storage account once, instantiate it multiple times with different inputs (DRY).
3. **Bicep private module registry** — publish a Bicep module to Azure Container Registry and consume it with a `br:` reference, the Bicep equivalent of a shared module library.

## Why this matters

In Lab 01 your Terraform state lived in a local file in Cloud Shell. That's fine solo, but on a team it's a disaster: no sharing, no locking, easy to lose. Remote state + locking is the single most important step toward production Terraform. Modules and a module registry are how you stop copy-pasting infrastructure and start reusing vetted, hardened building blocks.

## Prerequisites

- Lab 01 complete; working in Azure Cloud Shell (**bash**).
- `az account show` returns your subscription.
- Files created under `~/lab02` (the bootstrap script does this — see Setup).

---

## Setup — create the lab files

Paste the bootstrap block your trainer provides (or upload `bootstrap-lab02.sh`) to create `~/lab02` with all Terraform and Bicep files, then:
```bash
cd ~/lab02
ls -R
```

---

## Part A — Terraform remote state backend (≈30 min)

**1. Create the backend infrastructure with the CLI** (state storage must exist *before* Terraform can use it — chicken/egg, so we use `az`, not Terraform):
```bash
# Unique-ish storage account name for state
SA="tfstate$RANDOM$RANDOM"
az group create -n tfstate-rg -l eastus
az storage account create -n "$SA" -g tfstate-rg -l eastus \
  --sku Standard_LRS --encryption-services blob
az storage container create -n tfstate --account-name "$SA" --auth-mode login
echo "Backend storage account: $SA"    # <-- note this name
```

**2. Initialize Terraform against the remote backend.** The `backend "azurerm" {}` block in `providers.tf` is empty on purpose; we pass the values here:
```bash
cd ~/lab02/terraform
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=$SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=lab02.terraform.tfstate"
```
Look for **"Successfully configured the backend "azurerm"!"** Your state now lives in Azure, not on disk.

**3. See the locking in action (conceptual + real).** The azurerm backend takes a **blob lease** on the state file during any write. Deploy, and while it runs, a second `apply` would fail with a lock error. You'll deploy in Part B.

---

## Part B — Reusable module (≈30 min)

Look at `terraform/main.tf`: it calls the **same** `./modules/storage` module **twice** — once for a `data` account (LRS), once for a `logs` account (GRS). One module definition, two instances, different inputs.

**1. Validate & plan:**
```bash
terraform validate
terraform plan
```
Expect **3 to add**: the resource group + two storage accounts. Notice the plan labels them `module.storage_data...` and `module.storage_logs...`.

**2. Apply** (writes state to the remote backend, taking a lock while it does):
```bash
terraform apply -auto-approve
```

**3. Confirm state is remote, not local:**
```bash
ls -la     # there should be NO terraform.tfstate file here
az storage blob list --account-name "$SA" -c tfstate --auth-mode login -o table
```
You should see `lab02.terraform.tfstate` in the container — proof the state is centralized.

**4. Inspect the state and outputs:**
```bash
terraform output
terraform state list
```

---

## Part C — Bicep private module registry (≈30 min)

**1. Create an Azure Container Registry** (ACR doubles as a Bicep module registry):
```bash
ACR="azlab02acr$RANDOM"
az group create -n azlab02-registry-rg -l eastus
az acr create -n "$ACR" -g azlab02-registry-rg --sku Basic
echo "Registry: $ACR.azurecr.io"
```

**2. Publish the reusable Bicep module to the registry:**
```bash
cd ~/lab02/bicep
az bicep publish --file storage-module.bicep \
  --target "br:$ACR.azurecr.io/bicep/modules/storage:v1"
```

**3. Verify it's in the registry:**
```bash
az acr repository show-tags -n "$ACR" --repository bicep/modules/storage -o table
```

**4. Consume the published module.** `main.bicep` references it with `br:...`. Deploy, passing your registry:
```bash
az deployment sub create \
  --location eastus \
  --name lab02-bicep \
  --template-file main.bicep \
  --parameters registryLoginServer="$ACR.azurecr.io"
```
Bicep pulls the module straight from your registry (you'll see it restore `br:...`). That's a private, versioned, shareable module — the same pattern real teams use.

---

## Part D — Break & Diagnose (RCA) (≈15 min)

**State-lock scenario.** Start an apply, and while it's running open a *second* Cloud Shell tab and run `terraform apply` again in the same dir.
- *Diagnose:* Read the error — it names the lock, who holds it, and when it was acquired. Where is the lock actually stored? (Hint: blob lease on the state file.)
- *Fix:* Let the first run finish (correct answer), and understand when `terraform force-unlock <ID>` is/ isn't appropriate. Document why blindly force-unlocking is dangerous.

---

## Part E — Teardown (do not skip)

```bash
# Destroy the module-based stack (releases the state lock when done)
cd ~/lab02/terraform && terraform destroy -auto-approve

# Bicep stack + its registry
az group delete -n azlab02b-rg --yes --no-wait
az group delete -n azlab02-registry-rg --yes --no-wait

# Finally, the state backend itself (do this LAST — Terraform needs it until destroy is done)
az group delete -n tfstate-rg --yes --no-wait

# Verify
az group list --query "[?starts_with(name,'azlab02') || name=='tfstate-rg'].name" -o tsv
```

---

## Success criteria ✅

- [ ] Terraform state stored remotely in Azure Storage (verified in the blob container)
- [ ] One storage module reused for two different accounts (LRS + GRS)
- [ ] `terraform output` / `state list` work against remote state
- [ ] Bicep module published to ACR and consumed via a `br:` reference
- [ ] State-lock RCA understood and documented
- [ ] Everything torn down; no leftover resource groups

## Reflection questions

1. Why must the state storage account be created outside Terraform (with `az`) rather than by Terraform itself?
2. What exactly provides the lock in the azurerm backend, and what failure mode does it prevent?
3. When would you version a module `v1 → v2` in the registry, and how do consumers opt in?

---

When you finish (or hit an error), paste your outputs and I'll review, document it, and prep Lab 03.
