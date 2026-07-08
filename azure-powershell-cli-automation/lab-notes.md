# PowerShell, Azure CLI & Automation — Notes

> Trainer-maintained log.

**Date:** ______  **Environment:** Azure Cloud Shell (bash + PowerShell)

## Session log
Azure Cloud Shell — used both bash (az CLI) and PowerShell (pwsh 7.6.2, Az module).

## Part A — CLI vs PowerShell
- `az group list -o table` (CLI) → listed RGs with Name/Location/Status.
- Switched with `pwsh`; `Get-AzResourceGroup | Format-Table` → same RGs as objects.
- Difference: az = text/JSON, filter with --query (JMESPath), cross-platform; PowerShell = Verb-AzNoun commands returning objects you pipe into Where-Object/Sort-Object/Select-Object. Same Azure; choice is team preference.

## Part B — Automation script
- `cloud-report.sh` → full subscription report in one command: 11 RGs; resources by type; 3 stopped VMs (Gigi, ga-luxury-pools-vm, Magela-House-of-Fashion); long list of untagged resources (governance gap surfaced automatically).
- Real automation: one script replaces ~10 manual queries; schedulable for a daily snapshot.

## Part C — Azure Automation
- Created Automation Account `azauto-acct` (Basic SKU, state Ok) — the home for scheduled cloud scripts.
- Gotcha: the `az automation` extension is preview/experimental — `--assign-identity` isn't supported. Managed identity + runbook + schedule are finished in the Azure portal (Identity → System assigned On + Reader role; Runbooks → Create PowerShell runbook with Connect-AzAccount -Identity → Publish; Schedules → recurring, link to runbook).
- Concept understood: a runbook is a cloud-hosted script; a schedule runs it automatically; a managed identity gives it passwordless sign-in.

## Summary & outcome ✅
Became fluent in Azure's two command tools and turned commands into automation. Ran the same task in Azure CLI (text/JSON + JMESPath) and Azure PowerShell (objects + pipeline). Built a reusable cloud-report script (bash + PowerShell) that summarizes the estate and flags stopped VMs and untagged resources in one command. Created an Azure Automation Account for cloud-native scheduling and learned the runbook + schedule + managed-identity loop.

**Key takeaways**
- az CLI = cross-platform, text/JSON, filter with --query; PowerShell Az = object pipeline, Verb-AzNoun. Same Azure, team preference.
- A script turns many manual commands into one repeatable tool.
- Azure Automation runs runbooks (scripts) on a schedule in the cloud, signed in via a managed identity — no laptop, no stored password.
- Some CLI extensions are preview/limited; the portal is often the friendlier place for runbook authoring.

## Reflection answers
1.
2.
3.

## Teardown
- `az group delete -n azauto-rg --yes` removed the Automation Account. No role assignment was created (identity flag unsupported), so nothing else to clean. List empty.
