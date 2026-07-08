# Azure Administration — Locks, Tags, Lifecycle & Inventory

**Domain:** Azure Administration · **Stack:** Azure CLI · Resource locks · Tags · Storage lifecycle · Azure Resource Graph · Bicep · **Goal:** manage and protect a running estate day to day

## Objective

The everyday work of keeping an Azure estate healthy and safe:

- **Resource locks** — stop anyone (including you) from accidentally deleting important resources.
- **Tags at scale** — organize and find resources by team, environment, or project.
- **Storage lifecycle** — automatically move old data to cheaper tiers and delete it when it expires.
- **Inventory** — query your whole estate in seconds with Azure Resource Graph.

## Why this matters

Building things is one skill; *running* them safely is another. Admins are trusted with production, and the trust comes from careful habits — locking what matters, tagging so nothing is lost, automating cleanup, and always knowing what exists. This is the "keep the lights on" side employers rely on.

## Prerequisites

- Prior projects done; Azure Cloud Shell (**bash**); Owner on the subscription.
- Files under `~/azadmin`.

---

## Part A — Deploy a resource to manage (≈10 min)

```bash
az group create -n azadmin-rg -l eastus
cd ~/azadmin/bicep
az deployment group create -g azadmin-rg --name azadmin --template-file main.bicep
SA=$(az deployment group show -g azadmin-rg -n azadmin --query properties.outputs.storageAccountName.value -o tsv)
echo "SA=$SA"
```

---

## Part B — Resource locks: prevent accidental deletion (≈15 min)

**1. Put a "cannot delete" lock on the storage account:**
```bash
az lock create --name protect-storage --lock-type CanNotDelete \
  --resource-group azadmin-rg --resource-name "$SA" \
  --resource-type Microsoft.Storage/storageAccounts
```

**2. Now try to delete it — and watch the lock stop you:**
```bash
az storage account delete -n "$SA" -g azadmin-rg --yes
```
Expected: an error saying the resource is **locked** and can't be deleted. This is the safety net that prevents a mistyped command from wiping out something important.

**3. Confirm the lock exists:**
```bash
az lock list -g azadmin-rg -o table
```

(We'll remove the lock during teardown. Locks come in two kinds: `CanNotDelete` blocks deletion; `ReadOnly` blocks *any* change.)

---

## Part C — Tags at scale (≈10 min)

Tags organize your estate. Apply a couple to the resource group:
```bash
az group update -n azadmin-rg --set tags.environment=dev tags.costCenter=eng-42
```
Then **find resources by tag** across the whole subscription — how you locate things fast:
```bash
az resource list --tag environment=dev --query "[].{name:name, type:type, group:resourceGroup}" -o table
```
In a big estate, this is how you answer "show me everything owned by the platform team" or "everything in prod."

---

## Part D — Storage lifecycle: automate cleanup (≈15 min)

Old data shouldn't sit on expensive storage forever. A lifecycle policy moves it to a cheaper tier and eventually deletes it — automatically.

Create the policy file, then apply it:
```bash
cat > ~/azadmin/lifecycle.json <<'EOF'
{
  "rules": [
    {
      "enabled": true,
      "name": "cool-then-delete",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 30 },
            "delete": { "daysAfterModificationGreaterThan": 365 }
          }
        },
        "filters": { "blobTypes": [ "blockBlob" ] }
      }
    }
  ]
}
EOF

az storage account management-policy create --account-name "$SA" -g azadmin-rg --policy @~/azadmin/lifecycle.json
```
This rule: after 30 days move blobs to the **cool** (cheaper) tier; after 365 days **delete** them. Set once, runs forever — no manual cleanup.

Confirm it:
```bash
az storage account management-policy show --account-name "$SA" -g azadmin-rg --query "policy.rules[].name" -o table
```

---

## Part E — Inventory the whole estate with Resource Graph (≈10 min)

Azure Resource Graph queries *everything* across your subscription in one shot — the admin superpower for "what do I actually have?"

```bash
# Count of every resource type you own
az graph query -q "Resources | summarize count() by type | order by count_ desc" -o table

# Every storage account, with its location and resource group
az graph query -q "Resources | where type =~ 'microsoft.storage/storageAccounts' | project name, location, resourceGroup" -o table
```
(The first run installs the `resource-graph` extension — answer `Y`.) This is how admins audit, report, and find things at scale — the same skill behind a cost review.

---

## Part F — Teardown

```bash
# Remove the lock first (a locked resource group can't be deleted)
az lock delete --name protect-storage --resource-group azadmin-rg \
  --resource-name "$SA" --resource-type Microsoft.Storage/storageAccounts
az group delete -n azadmin-rg --yes
az group list --query "[?starts_with(name,'azadmin')].name" -o tsv
```
> Note: if you forget to remove the lock, the resource-group delete will fail — that's the lock doing its job.

---

## Success criteria ✅

- [ ] Deployed a resource to manage
- [ ] Placed a CanNotDelete lock and confirmed it blocked deletion
- [ ] Applied tags and found resources by tag across the subscription
- [ ] Applied a storage lifecycle policy (cool at 30d, delete at 365d)
- [ ] Queried the estate with Azure Resource Graph
- [ ] Understand locks (CanNotDelete vs ReadOnly), tag queries, lifecycle, and Resource Graph
- [ ] Removed the lock and cleaned up

## Reflection questions

1. When would you use a ReadOnly lock instead of CanNotDelete?
2. How do lifecycle policies save money without anyone doing manual work?
3. Why is Resource Graph better than clicking through the portal for a big estate?

---

Paste outputs as you go — I'll document it and this completes your Azure skills journey.
