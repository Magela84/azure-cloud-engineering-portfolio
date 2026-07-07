# Lab 04 — Notes & Documentation

> Trainer-maintained log. Filled in as you paste outputs.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. Note: shell variables don't persist across Cloud Shell sessions — re-capture ($KV, $SA, $ME, $KVID, $SAID) at the start of each session.

## Part A — Deploy building blocks
- `az deployment group create` → **Succeeded** (5.9s). Provisioned managed identity, RBAC Key Vault, keys-disabled storage, and the MI→Key Vault Secrets User role assignment in one shot.
- Managed Identity: `azlab04-mi` (principalId 6f7f6046-..., clientId 6ed44215-...)
- Key Vault: `azlab04-6bqbl-kv`
- Storage: `azlab046bqblsa` (allowSharedKeyAccess = false)

## Part B — Key Vault data-plane RBAC
- Initial secret write: **Forbidden / ForbiddenByRbac**, `Assignment: (not found)`. Confirms Owner (control-plane) has no data-plane secret access. Same lesson as Lab 2, on Key Vault.
- Role assigned: `Key Vault Secrets Officer` (roleDef b86a8fe4-...) at vault scope, to self.
- Retry after ~propagation: **secret set + read succeeded** → returned `s3cr3t`. Fixed access with a scoped data-plane role, not a key. Correct resolution of the Lab 2 control-plane/data-plane gap.

## Part C — Azure AD access to storage
- Key-based attempt: **KeyBasedAuthenticationNotPermitted** — account keys disabled at deploy (`allowSharedKeyAccess: false`). Security upgrade over Lab 2's key fallback.
- Role assigned: `Storage Blob Data Contributor` (roleDef ba92f5b4-...) at storage-account scope, to self.
- AAD access (--auth-mode login): **Success** — container created, `hello.txt` uploaded (15 bytes) and listed, all via Azure AD identity, zero keys. Blob shows server-side encrypted. Modern secure storage access proven end to end.

## Part D — Managed identity & service principal
- identity show: `azlab04-mi` with clientId 6ed44215-... and principalId 6f7f6046-... — no stored secret.
- sp show: `servicePrincipalType: ManagedIdentity` — the managed identity IS an Azure-managed service principal in Azure AD.
- MI role assignment: `Key Vault Secrets User` on the vault (read-only). Contrast with self = Secrets Officer (read+write) → least privilege: the app gets only what it needs.

## Part E — RCA (RBAC propagation)
- Symptom: right after granting a role, the operation can still return Forbidden / AuthorizationPermissionMismatch.
- Root cause: RBAC assignments are **eventually consistent** — they take ~1–2 minutes to propagate.
- Lesson: don't conclude a role "didn't work" immediately; verify the assignment exists (`az role assignment list`), then allow propagation time. (Same async theme as Lab 3 compliance data.)

## Reflection answers
1.
2.
3.

## Teardown
- Deleted resource group `azlab04-rg` (removes managed identity, vault, storage, and all their role assignments — self-assigned roles die with the resources, no need to delete separately).
- Purged the soft-deleted Key Vault.
- Gotcha (twice this lab): Cloud Shell shell variables ($KV, $ME, $KVID, $SAID) don't persist across sessions/tabs — re-capture them at the start of each session, or use literal resource names.

## Lab 04 — Summary & outcome ✅
Learned Azure identity & access hands-on and properly fixed the two "wrong way" moments from Lab 2. Deployed a user-assigned managed identity + RBAC Key Vault + keys-disabled storage via Bicep (with a role assignment in the template). Reproduced the Key Vault "Forbidden," fixed it with a scoped data-plane role, and wrote/read a secret. Proved storage account keys are disabled and accessed blobs purely with Azure AD. Inspected the managed identity as a service principal and confirmed its least-privilege role.

**Key takeaways**
- Control-plane role (Owner) ≠ data-plane access — reading secrets/blobs needs roles like Key Vault Secrets Officer / Storage Blob Data Contributor.
- Managed identity = passwordless Azure AD identity; it IS an Azure-managed service principal — no secrets to store.
- Disable storage shared-key access to force Azure AD (`--auth-mode login`); keys then return KeyBasedAuthenticationNotPermitted.
- Least privilege: the app identity got read-only Secrets User; the human got read/write Secrets Officer.
- RBAC assignments are eventually consistent (~1–2 min) — verify the assignment exists before assuming failure.
- System-assigned MI = tied to one resource's lifecycle; user-assigned = standalone and reusable across resources.
