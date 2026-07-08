# FinOps — Cloud Cost Management & Optimization

**Domain:** FinOps / Cost Optimization · **Stack:** Azure Cost Management · Budgets · Tags · Azure Policy · Bicep · **Goal:** see, control, and reduce cloud spend

## Objective

Money is a first-class concern in the cloud — it's easy to overspend without noticing. This project covers the core FinOps practices:

- **Budgets & alerts** — set a spending limit and get emailed *before* you blow past it.
- **Cost allocation with tags** — label resources so you can answer "who spent what."
- **Cost visibility** — query what you're actually spending.
- **Tag enforcement** — a policy so nothing gets created without a cost tag.
- **Optimization** — the standard ways to cut waste.

## Why this matters

FinOps is where engineering meets the finance team. Engineers who can show they *think about cost* — set budgets, tag for chargeback, right-size resources — are far more valuable than those who just spin things up and forget them. This is a real differentiator.

## Prerequisites

- Prior projects done; Azure Cloud Shell (**bash**); Owner on the subscription.
- Files under `~/azfin`.

---

## Part A — Set a budget with an alert (≈10 min)

Deploy a monthly budget that emails you at 80% of the limit (and earlier if you're *forecast* to overspend). **Replace the email with yours.**

```bash
cd ~/azfin/bicep
az deployment sub create --location eastus --name finops-budget \
  --template-file budget.bicep \
  --parameters alertEmail="your-email@example.com"
```
Confirm it exists:
```bash
az consumption budget list --query "[].{name:name, amount:amount, timeGrain:timeGrain}" -o table
```
Now Azure will email you *before* spending gets out of hand — the single most important cost control.

---

## Part B — Tag resources for cost allocation (≈10 min)

Deploy a resource labelled with cost tags. Tags are how cost reports answer "which team/project spent this?"

```bash
az group create -n azfin-rg -l eastus
az deployment group create -g azfin-rg --name finops-tagged \
  --template-file tagged-resource.bicep
```
See the tags on the resource:
```bash
SA=$(az deployment group show -g azfin-rg -n finops-tagged --query properties.outputs.storageAccountName.value -o tsv)
az resource show --ids $(az storage account show -n "$SA" --query id -o tsv) --query tags -o jsonc
```
You'll see `costCenter`, `environment`, `owner`, `project`. In Cost Management you can group the bill by any of these.

---

## Part C — See what you're spending (≈10 min)

Query recent usage/cost:
```bash
az consumption usage list --top 15 \
  --query "[].{resource:instanceName, meter:meterDetails.meterName, cost:pretaxCost, currency:currency}" -o table
```
On a lightly-used student subscription this may be small or empty — that's normal; the point is the tool. In a real environment this is how you spot the expensive resources.

> Tip: the richer view is the **Cost Management + Billing** blade in the Azure portal — Cost analysis lets you chart spend over time and group by tag, resource, or service.

---

## Part D — Enforce cost tags with policy (≈15 min)

Budgets tell you the total; tags tell you *where* it went — but only if everything is tagged. A policy makes sure nothing slips through untagged.

Deploy an **audit** policy that flags any resource group missing a `costCenter` tag (uses the built-in policy):
```bash
POL=$(az policy definition list --query "[?displayName=='Require a tag on resource groups'].name | [0]" -o tsv)
az policy assignment create --name require-costcenter-tag \
  --policy "$POL" \
  --params '{ "tagName": { "value": "costCenter" } }'
```
Now Azure will flag any resource group with no `costCenter` tag as non-compliant — so your cost reports stay complete.

---

## Part E — Optimization checklist (the ways to actually cut cost)

Knowing *how* to reduce spend is the FinOps payoff. The standard levers:

- **Right-size** — pick the smallest SKU/tier that meets the need; don't over-provision. LRS storage instead of GRS in dev; smaller VM sizes.
- **Turn off idle resources** — dev/test environments don't need to run 24/7. Auto-shutdown VMs; delete unused disks, IPs, and old snapshots.
- **Autoscale** — scale out under load and back in when quiet, instead of running big all the time.
- **Reservations & savings plans** — commit to 1 or 3 years for steady workloads to get big discounts versus pay-as-you-go.
- **Storage lifecycle** — move old blobs to cool/archive tiers automatically.
- **Tag + review** — you can't cut what you can't see; tagging plus a monthly cost review is the habit.

---

## Part F — Teardown

```bash
az group delete -n azfin-rg --yes
az policy assignment delete --name require-costcenter-tag
az consumption budget delete --budget-name monthly-cost-budget
az group list --query "[?starts_with(name,'azfin')].name" -o tsv
```
(Budgets cost nothing, but we clean it up to leave things tidy.)

---

## Success criteria ✅

- [ ] Deployed a monthly budget with an 80% email alert (and a forecast alert)
- [ ] Deployed a resource tagged for cost allocation; confirmed the tags
- [ ] Queried cost/usage data
- [ ] Assigned a policy requiring a `costCenter` tag
- [ ] Can list the main optimization levers (right-size, idle shutdown, autoscale, reservations, lifecycle, tag+review)
- [ ] Cleaned up

## Reflection questions

1. Why is a *forecast* alert useful on top of an *actual* spend alert?
2. How do tags turn one big bill into per-team/per-project accountability?
3. When would a 1- or 3-year reservation save money, and when would it be a mistake?

---

Paste outputs as you go — I'll document it and wrap up the FinOps module.
