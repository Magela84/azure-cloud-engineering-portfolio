# Monitoring & Observability — Metrics, Logs (KQL) & Alerts

**Domain:** Monitoring & Observability · **Stack:** Azure Monitor · Log Analytics · KQL · Metric Alerts · Bicep · **Goal:** see and query what your resources are doing, and get alerted

## Objective

Learn the three pillars of Azure observability by wiring them up on a real resource:

- **Metrics** — near-real-time numeric telemetry (transactions, latency, availability), queried directly from the Azure Monitor metrics API.
- **Logs (KQL)** — richer event/metric data ingested into a **Log Analytics workspace** and queried with **KQL** (Kusto Query Language).
- **Alerts** — rules that fire when a metric crosses a threshold.

You'll also learn the single most important operational nuance: **metrics are near-instant, but log ingestion into Log Analytics is delayed** — the thing that confuses everyone the first time.

## Why this matters

Troubleshooting a real incident *is* observability: you read metrics to see the symptom, query logs to find the cause, and alerts are what told you something was wrong in the first place. This is the toolset behind every "the site is slow — why?" investigation.

## Prerequisites

- Prior projects done; Azure Cloud Shell (**bash**); Owner on the subscription.
- Files under `~/azmon`.

---

## Part A — Deploy the workspace + resource (≈10 min)

```bash
az group create -n azmon-rg -l eastus
cd ~/azmon/bicep
az deployment group create -g azmon-rg --name azmon --template-file main.bicep
```
Capture the names/ids you'll need:
```bash
RG=azmon-rg
SA=$(az deployment group show -g $RG -n azmon --query properties.outputs.storageAccountName.value -o tsv)
WGUID=$(az deployment group show -g $RG -n azmon --query properties.outputs.workspaceGuid.value -o tsv)
SAID=$(az storage account show -n "$SA" --query id -o tsv)
echo "SA=$SA"; echo "WGUID=$WGUID"
```

---

## Part B — Generate some activity (≈5 min)

Create a container and a couple of blobs so the storage account has something to report:
```bash
az storage container create -n logs-demo --account-name "$SA" --auth-mode key
echo "hello monitoring" > m.txt
az storage blob upload --account-name "$SA" -c logs-demo -n m1.txt -f m.txt --auth-mode key
az storage blob upload --account-name "$SA" -c logs-demo -n m2.txt -f m.txt --auth-mode key
az storage blob list --account-name "$SA" -c logs-demo --auth-mode key -o table
```
Each call is a **transaction** the metrics system records.

---

## Part C — Metrics (near-real-time) (≈10 min)

Query the storage account's transaction metric **directly** — this is the metrics API, and it's near-instant:
```bash
az monitor metrics list --resource "$SAID" --metric Transactions \
  --interval PT1M --aggregation Total -o table
```
You should see transaction counts within a minute or two — no waiting for ingestion. This is what you'd check first during an incident.

Try another useful one — availability:
```bash
az monitor metrics list --resource "$SAID" --metric Availability \
  --aggregation Average -o table
```

---

## Part D — Activity Log (control-plane audit) (≈5 min)

The Activity Log records *who did what* to your resources (deployments, config changes) — no workspace needed, available immediately:
```bash
az monitor activity-log list --resource-group $RG --offset 1h \
  --query "[].{time:eventTimestamp, operation:operationName.localizedValue, caller:caller, status:status.value}" -o table
```
This is your audit trail — invaluable when something changed and you need to know who/when.

---

## Part E — Logs & KQL in Log Analytics (delayed — teaches ingestion latency) (≈20 min)

The diagnostic setting streams storage metrics into your workspace, where you query them with **KQL**. Run a query:
```bash
az monitor log-analytics query -w "$WGUID" \
  --analytics-query "AzureMetrics | where ResourceProvider == 'MICROSOFT.STORAGE' | project TimeGenerated, MetricName, Total | take 20" -o table
```

**Expect this to be EMPTY at first.** Log ingestion into a workspace typically takes **5–15 minutes** on a new setup — unlike the metrics API in Part C, which is near-instant. This delay is the #1 "why is my query empty?" gotcha. Wait ~10 minutes and re-run.

More KQL to try once data lands (learn the query language):
```bash
# Count records by metric name
az monitor log-analytics query -w "$WGUID" --analytics-query "AzureMetrics | summarize count() by MetricName" -o table

# What tables exist in the workspace
az monitor log-analytics query -w "$WGUID" --analytics-query "search * | distinct \$table | take 20" -o table
```
KQL reads left-to-right, piping (`|`) data through operators: `where` (filter), `project` (pick columns), `summarize` (aggregate), `take` (limit). That pattern covers most day-to-day queries.

---

## Part F — Create a metric alert (≈15 min)

Alert when the storage account records any transactions (a stand-in for "unusual activity"):
```bash
az monitor metrics alert create \
  --name azmon-transactions-alert -g $RG \
  --scopes "$SAID" \
  --condition "total Transactions > 0" \
  --description "Fires when the storage account records transactions" \
  --evaluation-frequency 1m --window-size 5m --severity 3
```
Confirm it exists:
```bash
az monitor metrics alert list -g $RG -o table
```
In production you'd attach an **action group** (email/SMS/webhook/Teams) so the alert actually notifies someone — that's the next step beyond this lab.

---

## Part G — Break & Diagnose (RCA) (≈10 min)

**Scenario — "my KQL query returns nothing."**
- *Diagnose:* Is it too soon (ingestion latency)? Is the diagnostic setting actually sending data (`az monitor diagnostic-settings list --resource "$SAID"`)? Is the table name right (`AzureMetrics`, not `Metrics`)? Did any activity occur to generate data?
- *Lesson:* Empty ≠ broken. Metrics API is near-real-time; **Log Analytics ingestion lags minutes**. Always confirm the diagnostic setting exists and give ingestion time before concluding something's wrong.

---

## Part H — Teardown

```bash
az group delete -n azmon-rg --yes
az group list --query "[?starts_with(name,'azmon')].name" -o tsv
```
(No Key Vault this project, so nothing to purge.)

---

## Success criteria ✅

- [ ] Deployed a Log Analytics workspace + storage + diagnostic setting via Bicep
- [ ] Generated activity and read the Transactions metric via the near-real-time metrics API
- [ ] Read the Activity Log audit trail
- [ ] Ran KQL against the workspace (and understood ingestion latency)
- [ ] Created a metric alert rule
- [ ] Can explain metrics-API vs log-ingestion timing, and basic KQL (`where` / `project` / `summarize`)
- [ ] Everything torn down

## Reflection questions

1. When would you use the metrics API vs a KQL query in Log Analytics?
2. Why does a Log Analytics query return nothing immediately after you generate activity?
3. What turns an alert *rule* into an actual notification (email/Teams)?

---

Paste outputs as you go — I'll document it and wrap up the Monitoring module.
