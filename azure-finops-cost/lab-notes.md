# FinOps — Notes & Documentation

> Trainer-maintained log.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. FinOps / cost module.

## Part A — Budget + alert
- `az deployment sub create` (budget.bicep) → **Succeeded**. Created `monthly-cost-budget` ($50/month) at subscription scope.
- Two notifications to my email: 80% of Actual spend, and 100% of Forecast (predicts overspend before it happens).
- `az consumption budget list` → confirmed monthly-cost-budget, 50.0, Monthly.

## Part B — Tags for cost allocation
- Deployed tagged storage `azfin6yn5xsa` in `azfin-rg`.
- Tags confirmed: costCenter=engineering-123, environment=dev, owner=platform-team, project=finops-demo. Cost Management can group the bill by any of these.

## Part C — Cost visibility (real cost review!)
- `az consumption usage list` surfaced the whole subscription inventory (cost showed None — sponsored/student sub).
- Inventory (`az group list`, `az resource list`) revealed **3 VMs** from other projects: Gigi, ga-luxury-pools-vm, Magela-House-of-Fashion — each with a disk + public IP.
- Power state (`az vm list -d`): all **deallocated (stopped)** — so no compute charges. Big cost already avoided.
- FinOps nuance learned: a deallocated VM still costs a little (managed disk + static IP are billed while they exist). "Stopped" ≠ "free." To reach zero, delete the resource group; to keep the restart option, leave it stopped.
- Real-world action: reviewed forgotten resources, confirmed the expensive part (compute) was off, understood the residual disk/IP cost and the delete-vs-keep tradeoff.

## Part D — Tag-enforcement policy (concept)
- Pattern: assign the built-in "Require a tag on resource groups" policy with tagName = costCenter so nothing is created untagged and cost reports stay complete. (Reused the policy skill from the governance project.)

## Part E — Optimization levers (learned)
- Right-size · turn off idle · autoscale · reservations/savings plans · storage lifecycle · tag + monthly review.

## Teardown
- `az group delete -n azfin-rg --yes` (removed the lab's tagged storage) and `az consumption budget delete` (removed the budget). Personal-project VMs left stopped/untouched.

## Summary & outcome ✅
Learned to see, control, and cut cloud spend. Deployed a monthly budget with actual (80%) and forecast (100%) email alerts via Bicep; tagged resources for cost allocation (costCenter/owner/environment/project); ran a real cost review that surfaced three forgotten VMs (all already deallocated) and learned that stopped VMs still cost a little for disks/IPs; covered the optimization levers.

**Key takeaways**
- A budget with alerts is the #1 cost control — get warned before you overspend (forecast alerts warn even earlier).
- Tags turn one bill into per-team/per-project accountability; enforce them with policy.
- Cost review = inventory what exists, find idle/forgotten resources (VMs, disks, IPs are the big ones).
- A deallocated VM stops compute charges but still bills for its disk and static IP — "stopped" isn't "free."
- Cut cost by: right-sizing, shutting down idle, autoscaling, reservations/savings plans, storage lifecycle tiers, and a regular tag-based review.

## Reflection answers
1.
2.
3.

## Teardown confirmation
- [ ] Resource group deleted
- [ ] Policy assignment deleted
- [ ] Budget deleted
- [ ] Lists clean
