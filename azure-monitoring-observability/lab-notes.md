# Monitoring & Observability — Notes & Documentation

> Trainer-maintained log. Filled in as you paste outputs.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. Monitoring & Observability module.

## Part A — Deploy
- `az deployment group create` → **Succeeded** (24s). Log Analytics workspace + storage + diagnostic setting.
- Workspace `azmon-law` (GUID 69b29874-3855-40fc-ab72-348eb1d21277), storage `azmon5dkp7sa`, diagnostic setting `send-to-law` (streams storage Transaction metrics → workspace).

## Part B — Generate activity
- Created container `logs-demo`, uploaded m1.txt + m2.txt, listed. Each call = a storage transaction (the telemetry we'll observe).

## Part C — Metrics (near-real-time)
- Transactions: 0.0 for idle minutes, then **4.0 at 09:05Z** — the exact activity from Part B, visible seconds-to-a-minute later. Near-real-time.
- Availability: blank while idle, **100.0 at 09:05Z** — only reports when there's traffic (% of successful requests). Account healthy.
- Takeaway: the metrics API is what you check first in an incident — is it up (availability), what's the load (transactions) — answered in seconds.

## Part D — Activity Log
- Full control-plane audit trail returned: Update resource group → Validate/Create Deployment → Create Workspace + Storage → diagnostic setting → then Part B's `List Storage Account Keys`. Every event stamped with caller (annor04@...) and status. Immediate, no workspace needed. This is the "who changed what, when" trail for incidents.

## Part E — Logs & KQL
- Installed the `log-analytics` az extension (first-time prompt).
- First query `AzureMetrics | where ResourceProvider == 'MICROSOFT.STORAGE' | project ... | take 20` → **EMPTY** (ingestion latency — same data was instant in the metrics API).
- After ~10 min: query **returned rows** — Transactions/Ingress/Egress/latency/Availability at 09:05Z. Same activity that was instant in the metrics API, now queryable as logs (and richer — bytes, latency, etc.).
- `summarize count() by MetricName` → 3 records per metric. Aggregation working.
- KQL structure learned: pipe (`|`) chains operators top-to-bottom — table → `where` (filter rows) → `project` (pick columns) → `summarize` (aggregate) → `take` (limit).
- Insight: metrics API = instant but simple ("is it broken now?"); Log Analytics = delayed but deep/queryable ("investigate what happened").

## Part F — Metric alert
- Created `azmon-transactions-alert` (enabled): condition Total Transactions > 0, eval every 1m over 5m window, severity 3, scoped to the storage account.
- Production next step: attach an action group (email/Teams/webhook) so the rule actually notifies.

## Part G — RCA (ingestion latency)
- **Symptom:** KQL query returned empty right after generating activity, even though the metrics API showed it instantly.
- **Root cause:** Log Analytics ingestion is delayed (~5–15 min on a fresh setup); the metrics API is near-real-time. Empty ≠ broken.
- **Diagnosis checklist:** confirm the diagnostic setting exists (`az monitor diagnostic-settings list --resource <id>`), correct table name (`AzureMetrics`), activity actually occurred, and enough time has passed.
- **Lesson:** for "is it broken now?" use the metrics API; for investigation use KQL, and allow ingestion time before concluding data is missing.

## Reflection answers
1.
2.
3.

## Teardown
- `az group delete -n azmon-rg --yes` → workspace, storage, diagnostic setting, and alert removed. `az group list` (azmon*) → empty. Clean.

## Summary & outcome ✅
Wired up all four pillars of Azure observability on a live resource. Deployed a Log Analytics workspace + storage + diagnostic setting via Bicep; read near-real-time metrics (Transactions/Availability); reviewed the Activity Log audit trail; queried logs with KQL (where/project/summarize/take) after learning the ingestion-latency gotcha; and created a metric alert rule.

**Key takeaways**
- Metrics API is near-real-time (seconds–minute) — check it first in an incident ("is it up? what's the load?").
- Log Analytics is deeper/queryable but ingestion is delayed ~5–15 min — empty ≠ broken.
- Activity Log = control-plane audit ("who did what, when"), available immediately, no workspace needed.
- KQL: pipe operators top-to-bottom — table → where → project → summarize → take.
- An alert *rule* only notifies once you attach an action group (email/Teams/webhook).
