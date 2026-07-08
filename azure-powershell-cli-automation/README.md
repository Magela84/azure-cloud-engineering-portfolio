# PowerShell, Azure CLI & Automation

**Domain:** Scripting & Automation · **Stack:** Azure CLI (`az`) · Azure PowerShell (Az module) · Bash · Azure Automation · **Goal:** manage Azure with scripts, and let those scripts run themselves

## Objective

The two command-line tools for Azure, and how to turn commands into automation:

- **Azure CLI (`az`)** — the cross-platform tool you've used throughout. Text and JSON output, great in bash.
- **Azure PowerShell (Az module)** — the object-oriented tool. Commands are `Verb-AzNoun` (e.g. `Get-AzResourceGroup`), and results are objects you pipe around. Strong in Windows shops.
- **Automation** — wrap commands in a script so a repetitive task runs the same way every time, then schedule it so it runs *without you*.

## Why this matters

Clicking is fine once; scripting is how professionals do anything more than once. And automation — a script that runs on a schedule — is what keeps an estate healthy without someone remembering to do it. Being fluent in both `az` and PowerShell, and comfortable turning them into automation, is a core cloud-engineer skill.

## Prerequisites

- Prior projects done; Azure Cloud Shell (**bash**), which also has PowerShell built in.
- Files under `~/azauto`.

---

## Part A — The same task in both tools (≈10 min)

**Azure CLI** (you're in bash):
```bash
az group list -o table
```

Now switch Cloud Shell to **PowerShell** — just type:
```bash
pwsh
```
Your prompt changes to `PS ...>`. The **Az module** is preloaded and already signed in. Run the PowerShell equivalent:
```powershell
Get-AzResourceGroup | Format-Table ResourceGroupName, Location
```

Same result, two styles. The difference:
- `az` returns **text/JSON** — you filter with `--query` (JMESPath). Great in bash and cross-platform.
- PowerShell returns **objects** — you pipe them into `Where-Object`, `Sort-Object`, `Select-Object`. Great for richer scripting, especially on Windows.

Both authenticate to the *same* Azure. Which you use is team preference. To go back to bash, type:
```powershell
exit
```

---

## Part B — Automation: a reusable "cloud report" script (≈15 min)

A script turns a set of commands into a repeatable tool. This one summarizes your whole subscription. Run it (bash version):
```bash
bash ~/azauto/scripts/cloud-report.sh
```
It prints: total resource groups, resources by type, stopped VMs (cost candidates), and resources missing an `owner` tag. That last one is a mini-governance check — it flags anything untagged.

There's a **PowerShell version** too (`cloud-report.ps1`) — the same report, the PowerShell way. Run it in PowerShell mode:
```powershell
pwsh
~/azauto/scripts/cloud-report.ps1
exit
```

This is real automation: one command, a full snapshot. You could run it every morning and paste it into a channel — no manual clicking.

---

## Part C — Cloud-native scheduling: Azure Automation (≈20 min)

A script on your laptop only runs when you run it. **Azure Automation** runs scripts *in the cloud, on a schedule*, with no computer of yours involved. The pieces:

- **Automation Account** — the home for your cloud scripts.
- **Runbook** — a script (PowerShell or Python) that lives in the account.
- **Managed identity** — how the runbook signs in to Azure (passwordless — the same idea from the identity project).
- **Schedule** — when it runs (e.g. every morning at 6am).

Create the Automation Account with a managed identity, and give that identity permission to read the subscription:
```bash
az group create -n azauto-rg -l eastus
az automation account create --name azauto-acct -g azauto-rg -l eastus --assign-identity

MI=$(az automation account show --name azauto-acct -g azauto-rg --query identity.principalId -o tsv)
SUB=$(az account show --query id -o tsv)
az role assignment create --assignee-object-id "$MI" --assignee-principal-type ServicePrincipal \
  --role "Reader" --scope "/subscriptions/$SUB"
```

Then you author the **runbook** and attach a **schedule**. Runbook editing and scheduling are much friendlier in the **Azure portal**:
1. Portal → your Automation Account → **Runbooks** → **Create a runbook** (PowerShell).
2. Paste a script that starts with `Connect-AzAccount -Identity` (signs in as the managed identity), then does the work.
3. **Publish** it, then under **Schedules** create a recurring schedule and link it.

That's the full loop: a script that runs itself in the cloud, forever, signed in passwordlessly.

> If `az automation` reports it needs an extension, accept the install. Runbook content and schedules can also be done via CLI, but the portal editor is the easier place to learn them.

---

## Part D — Teardown

```bash
az group delete -n azauto-rg --yes
az role assignment delete --assignee-object-id "$MI" --scope "/subscriptions/$(az account show --query id -o tsv)" 2>/dev/null || true
az group list --query "[?starts_with(name,'azauto')].name" -o tsv
```

---

## Success criteria ✅

- [ ] Ran the same query in both Azure CLI and Azure PowerShell
- [ ] Can explain the difference (text/JSON + JMESPath vs objects + pipeline)
- [ ] Ran the reusable cloud-report automation script
- [ ] Created an Automation Account with a managed identity (cloud-native scheduling)
- [ ] Understand runbooks + schedules + managed-identity sign-in
- [ ] Cleaned up

## Reflection questions

1. When would you prefer PowerShell over the Azure CLI, and vice versa?
2. What does scheduling a script in Azure Automation give you that a script on your laptop doesn't?
3. Why does a runbook use a managed identity instead of a stored credential?

---

Paste outputs as you go — I'll document it.
