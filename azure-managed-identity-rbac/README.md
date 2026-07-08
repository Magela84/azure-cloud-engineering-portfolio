# Managed Identity & RBAC — Passwordless Access

**Domain:** Security & Identity · **Stack:** Entra ID · Managed Identity · RBAC (data-plane) · Key Vault · Bicep · **Model:** Azure AD-only auth (no keys)

## Objective

Master how identity and access actually work in Azure — and properly fix the two things you saw "the wrong way" in earlier labs:

- In Lab 2, you couldn't read your own storage because Owner is **control-plane**, not **data-plane** — you used a key workaround. Now you'll fix it correctly with a **data-plane RBAC role**.
- In Lab 2, Terraform used the storage **account key**. Here the storage account has **shared-key auth disabled**, so the *only* way in is **Azure AD** — the secure model.

You'll work with **managed identities** (passwordless identities for Azure resources), **RBAC role assignments**, **Key Vault secrets**, and **service principals**.

## Key concepts (quick)

- **Managed identity:** an Azure AD identity Azure manages for you — no passwords or keys to store. *System-assigned* is tied to one resource; *user-assigned* is standalone and reusable.
- **Service principal:** the identity an app/identity uses to authenticate to Azure AD. A managed identity is a special, Azure-managed service principal.
- **Control plane vs data plane:** control plane = manage the resource (create/delete); data plane = use the data inside (read a secret, read a blob). **Different RBAC roles.**
- **RBAC role assignment** = principal + role + scope. Assignments take a minute or two to propagate.

## Prerequisites

- Labs 1–3 done; Azure Cloud Shell (**bash**); Owner + User Access Administrator on the subscription (needed to create role assignments).
- Files under `~/lab04` (paste the bootstrap block).

---

## Part A — Deploy the identity building blocks (≈15 min)

```bash
az group create -n azlab04-rg -l eastus
cd ~/lab04/bicep
az deployment group create -g azlab04-rg --name lab04 --template-file main.bicep
```
Expect `Succeeded` with outputs: managed identity name/ids, Key Vault name, storage account name. Capture the names:
```bash
KV=$(az deployment group show -g azlab04-rg -n lab04 --query properties.outputs.keyVaultName.value -o tsv)
SA=$(az deployment group show -g azlab04-rg -n lab04 --query properties.outputs.storageAccountName.value -o tsv)
echo "Vault: $KV   Storage: $SA"
```

---

## Part B — Data-plane RBAC on Key Vault (the Lab 2 lesson, fixed) (≈20 min)

**1. Try to write a secret — and watch it fail.** Even though you're Owner:
```bash
az keyvault secret set --vault-name "$KV" --name demo-secret --value "s3cr3t"
```
Expected: **Forbidden** — Owner is control-plane; writing secrets needs a **data-plane** role. This is exactly the Lab 2 gap, now on Key Vault.

**2. Grant yourself the data-plane role.** Get your identity, then assign "Key Vault Secrets Officer" (read + write secrets) at the vault scope:
```bash
ME=$(az ad signed-in-user show --query id -o tsv)
KVID=$(az keyvault show --name "$KV" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Key Vault Secrets Officer" --scope "$KVID"
```

**3. Wait ~1–2 min for propagation, then retry:**
```bash
az keyvault secret set --vault-name "$KV" --name demo-secret --value "s3cr3t"
az keyvault secret show --vault-name "$KV" --name demo-secret --query value -o tsv
```
Now it **works** and returns `s3cr3t`. You fixed the access the *right* way — a scoped data-plane role, not a key.

---

## Part C — Azure AD access to storage (shared-key disabled) (≈20 min)

The storage account was deployed with `allowSharedKeyAccess: false`, so account keys simply don't work — Azure AD is the only way in.

**1. Prove keys are dead:**
```bash
az storage container create -n data --account-name "$SA" --auth-mode key
```
Expected: **error** — shared-key auth is disabled.

**2. Grant yourself the data-plane storage role:**
```bash
SAID=$(az storage account show -n "$SA" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SAID"
```

**3. Wait ~1–2 min, then use Azure AD auth (`--auth-mode login`):**
```bash
az storage container create -n data --account-name "$SA" --auth-mode login
echo "hello identity" > hello.txt
az storage blob upload --account-name "$SA" -c data -n hello.txt -f hello.txt --auth-mode login
az storage blob list --account-name "$SA" -c data --auth-mode login -o table
```
It works — authenticated entirely by your Azure AD identity, no keys anywhere.

---

## Part D — Inspect the managed identity & its service principal (≈10 min)

```bash
az identity show -g azlab04-rg -n azlab04-mi --query "{name:name, clientId:clientId, principalId:principalId}" -o jsonc

# The managed identity IS a service principal in Azure AD — look it up by its principalId:
MIP=$(az identity show -g azlab04-rg -n azlab04-mi --query principalId -o tsv)
az ad sp show --id "$MIP" --query "{displayName:displayName, servicePrincipalType:servicePrincipalType}" -o jsonc

# Confirm the role the template granted it (Key Vault Secrets User on the vault):
az role assignment list --assignee "$MIP" --scope "$KVID" -o table
```
This is how a passwordless app works: the managed identity authenticates as its service principal and its RBAC role decides what it can touch — no secrets stored anywhere.

---

## Part E — Break & Diagnose (RCA) (≈10 min)

**Scenario — "I gave the role but access is still denied."** Right after a role assignment, retry the operation *immediately* (before waiting).
- *Diagnose:* It may still fail. Why? RBAC assignments are **eventually consistent** — they take a minute or two to propagate. Confirm the assignment exists with `az role assignment list --assignee "$ME" --scope "$KVID" -o table`.
- *Lesson:* Don't conclude a role "didn't work" instantly — verify the assignment exists, then allow propagation time. (Same async theme as Lab 3's compliance data.)

---

## Part F — Teardown

```bash
# Remove the role assignments you added to yourself
az role assignment delete --assignee-object-id "$ME" --role "Key Vault Secrets Officer" --scope "$KVID"
az role assignment delete --assignee-object-id "$ME" --role "Storage Blob Data Contributor" --scope "$SAID"

# Delete the resource group (removes MI, vault, storage, and the MI's role assignment)
az group delete -n azlab04-rg --yes --no-wait

# Purge the soft-deleted vault
az keyvault purge --name "$KV"

# Verify
az group list --query "[?starts_with(name,'azlab04')].name" -o tsv
```

---

## Success criteria ✅

- [ ] Deployed a managed identity + RBAC Key Vault + shared-key-disabled storage via Bicep
- [ ] Reproduced the Key Vault "Forbidden," fixed it with a data-plane role, wrote & read a secret
- [ ] Confirmed account keys are dead on storage; accessed blobs with Azure AD (`--auth-mode login`)
- [ ] Inspected the managed identity's service principal and its granted role
- [ ] Understand control-plane vs data-plane, managed identity vs service principal, and RBAC propagation delay
- [ ] Everything torn down; vault purged

## Reflection questions

1. When would you use a **system-assigned** vs **user-assigned** managed identity?
2. Why is a managed identity more secure than storing a client secret or storage key in your app config?
3. You granted yourself "Secrets Officer" but the app identity only "Secrets User" — why the difference (least privilege)?

---

Paste outputs as you go — I'll document it and prep the next lab (secrets, encryption & network security).
