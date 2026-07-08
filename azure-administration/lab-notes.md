# Azure Administration — Notes & Documentation

> Trainer-maintained log.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. Azure Administration module (the final one).

## Part A — Deploy
- `az deployment group create` → Succeeded. Storage `azadmin6n6tpsa` in `azadmin-rg` (tagged environment=dev, owner=platform-team).

## Part B — Resource locks
- Created `protect-storage` (CanNotDelete) on the storage account.
- Delete attempt: **BLOCKED** — `(ScopeLocked) ... cannot perform delete operation because following scope(s) are locked ... remove the lock and try again.` The safety net working.
- `az lock list` confirmed protect-storage / CanNotDelete on azadmin-rg.
- Two lock types: CanNotDelete (blocks deletion), ReadOnly (blocks any change). Locks even override Owner — you must remove the lock first.

## Part C — Tags at scale
- Applied tags to the RG: environment=dev, costCenter=eng-42.
- `az resource list --tag environment=dev` → found azadmin6n6tpsa. Subscription-wide tag search — how you locate resources fast in a big estate.

## Part D — Storage lifecycle
- Applied `cool-then-delete` policy: tierToCool at 30 days, delete at 365 days (blockBlob).
- `management-policy show` confirmed the rule. Automatic tiering + cleanup, set once — no manual work, saves storage cost over time.

## Part E — Resource Graph inventory
- Installed the resource-graph extension (first use).
- `Resources | summarize count() by type` → 12 resource types across the subscription.
- `Resources | where type =~ storageAccounts | project name, location, resourceGroup` → listed azadmin6n6tpsa + Cloud Shell storage.
- Gotcha: `az graph query` wraps results — extract rows with `--query data`.
- Full-circle: Resource Graph uses KQL, the same language as monitoring logs. One query language for inventory AND log analysis.

## Reflection answers
1.
2.
3.

## Teardown
- Removed the lock (required first — a locked resource can't be deleted), then deleted azadmin-rg. List returned empty. Personal resources untouched.

## Summary & outcome ✅
Learned the day-to-day management of a running Azure estate. Placed a CanNotDelete lock and proved it blocks deletion; applied tags and searched the subscription by tag; attached a storage lifecycle policy that auto-tiers and deletes old blobs; and inventoried the whole estate with Azure Resource Graph (KQL).

**Key takeaways**
- Locks protect against accidental deletion/change and even override Owner — CanNotDelete blocks deletion, ReadOnly blocks any change. Remove the lock before deleting.
- Tags organize the estate; `az resource list --tag` finds resources subscription-wide.
- Storage lifecycle policies auto-tier and auto-delete old data — cost savings with zero manual work.
- Azure Resource Graph queries the whole estate in seconds using KQL (same language as monitoring logs); extract rows with `--query data`.
- Running things safely (locks, tags, lifecycle, inventory) is the trust that comes with production access.
