# Lab 02 — Notes & Documentation

> Trainer-maintained log. I'll fill this in as you paste outputs.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Working in Azure Cloud Shell (bash), region eastus. Continuation of the IaC track after Lab 01.

## Part A — Remote state backend
- Created backend infra with `az` (before Terraform, since state store must pre-exist): RG `tfstate-rg`, storage account `tfstate183266389`, container `tfstate`.
- `terraform init -backend-config=...` → **"Successfully configured the backend azurerm!"** + azurerm v4.80.0 installed. State now remote.
- Security note: backend storage was created with a bare `az storage account create`, so it defaulted to `minimumTlsVersion: TLS1_0`. In production the state store (holds all infra secrets) should be hardened with `--min-tls-version TLS1_2`. Flagged, not fixed (throwaway lab).

## Part B — Reusable module
- One `./modules/storage` module instantiated twice via `module "storage_data"` (LRS) and `module "storage_logs"` (GRS) — same code, different inputs (DRY).
- `terraform validate` → valid. `terraform plan` → **`3 to add`** (RG + 2 storage accounts); resources tracked under `module.storage_data.*` / `module.storage_logs.*`.
- Callback to Lab 01: no inline `network_rules` block, so no phantom drift this time (`network_rules (known after apply)`).
- `terraform apply -auto-approve` → **`Apply complete! Resources: 3 added`**. Outputs: `azlab02edbbddata` (LRS), `azlab02edbbdlogs` (GRS).
- Confirmed state is remote: `ls` showed NO local `terraform.tfstate`; blob list showed `lab02.terraform.tfstate` (21 KB, application/json) in the `tfstate` container. State centralized in Azure. ✅

### RCA (bonus) — "I can't read my own storage" (control-plane vs data-plane RBAC)
- **Symptom:** `az storage blob list --auth-mode login` → "You do not have the required permissions" (needs Storage Blob Data Reader/Contributor).
- **Root cause:** Owner/Contributor is *control-plane* access (create/delete the account) and does NOT grant *data-plane* access (read blobs). Those are separate RBAC scopes; `--auth-mode login` uses the Azure AD identity, which had no data role.
- **Why Terraform still worked:** the azurerm backend authenticates with the storage *account key* (shared-key) by default, bypassing RBAC entirely.
- **Fix / options:** (a) `--auth-mode key` (control-plane role can fetch the key) to view now; (b) properly, assign `Storage Blob Data Reader/Contributor` for AAD access. Disabling shared-key + forcing AAD is a security hardening topic for Lab 06.
- **Lesson:** control-plane role ≠ data-plane access — one of the most common real-world Azure access tickets.

## Part C — Bicep module registry
- Registry: `azlab02acr2240.azurecr.io` (ACR Basic).
- Published module: `az bicep publish --file storage-module.bicep --target br:.../bicep/modules/storage:v1`; verified with `az acr repository show-tags` → `v1`.
- Deployed `main.bicep` (consumes the module via `br:` reference) → **Succeeded**; created `azlab02b-rg` + storage `azlab02bgaxusdata`. The template held no storage logic — it pulled the module from the registry.

### RCA — Bicep module paths can't be interpolated
- **Symptom:** deploy failed with `BCP092: String interpolation is not supported in file paths` on `br:${registryLoginServer}/...`.
- **Root cause:** Bicep resolves module references at COMPILE time, before parameter values exist — so module paths must be compile-time literals, not built from params.
- **Fix (lab):** hardcoded the real registry into the path with sed.
- **Fix (production):** define a module ALIAS in `bicepconfig.json` mapping a friendly name to the registry, then reference `br/alias:bicep/modules/storage:v1`. Keeps the `.bicep` path literal AND environment-independent.
- Left a harmless `no-unused-params` warning since the param is no longer referenced after hardcoding.

## Part D — State locking (covered implicitly)
- Locking was exercised on every remote apply: the azurerm backend takes a blob lease on `lab02.terraform.tfstate` during writes, blocking concurrent applies. The hands-on two-tab race was skipped to keep momentum; concept understood.
- `terraform force-unlock <ID>` exists but is dangerous — only use it when certain no other run holds the lock, or you risk state corruption.

## Part E — Teardown
- `terraform destroy -auto-approve` → **`Destroy complete! Resources: 3 destroyed`** (also released the state lock).
- `az group delete` (--no-wait) for `azlab02b-rg`, `azlab02-registry-rg`, `tfstate-rg`. Deletion runs in background; verify list returns empty after a minute.

## Lab 02 — Summary & outcome ✅
Made Lab 01's IaC team-grade. Moved Terraform state to a shared Azure Storage backend with blob-lease locking; refactored a hardened storage account into a reusable module and instantiated it twice (LRS data + GRS logs); published a Bicep module to a private ACR registry and consumed it via a `br:` reference.

**Skills:** remote state + locking, backend bootstrapping, reusable Terraform modules, Bicep module registries (publish/consume/version), and three real RCAs.

**Key takeaways**
- State backend must pre-exist (created with `az`, not Terraform) — chicken/egg.
- Remote state + locking is the #1 step toward team Terraform.
- One module, many instances with different inputs = DRY.
- Control-plane role (Owner/Contributor) ≠ data-plane access (Storage Blob Data roles).
- Terraform's azurerm backend uses shared-key auth by default (bypasses RBAC).
- Bicep module paths must be compile-time literals — no interpolation; use `bicepconfig.json` aliases in production.
- Don't declare inline defaults that equal Azure defaults (avoids phantom drift — Lab 01 lesson applied).

## Reflection answers
1.
2.
3.

## Teardown confirmation
- [ ] Terraform destroyed
- [ ] Bicep RG deleted
- [ ] Registry RG deleted
- [ ] State backend RG deleted
- [ ] `az group list` clean
