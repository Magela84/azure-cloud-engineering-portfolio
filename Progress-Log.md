# Progress Log

A running record of completed labs. Add a row each time you finish one.

| Date | Lab | Skill area | Outcome | Time | Notes / RCA highlight |
|------|-----|-----------|---------|------|----------------------|
| 2026-07-04 | Lab 01 | IaC — Bicep/Terraform | ✅ Completed | ~2h | Deployed same secure stack in both tools (5 vs 7 resources); RCA on phantom `network_rules` drift — verified live resource matched config, root-caused to azurerm Allow-default quirk, fixed by removing redundant block. Full teardown, environment clean. |
| 2026-07-05 | Lab 02 | IaC — Modules & Remote State | ✅ Completed | ~1.5h | Remote Terraform state in Azure Storage + blob-lease locking; reusable storage module instantiated twice (LRS/GRS); published & consumed a Bicep module from private ACR. 3 RCAs: control-plane vs data-plane RBAC, Bicep no-interpolation-in-module-paths, shared-key backend auth. Full teardown. |
| 2026-07-06 | Lab 03 | Governance as Code (Azure Policy) | ✅ Completed | ~1h | Custom Bicep deny-policy (public blob) — blocked bad account, allowed compliant one; built-in "Allowed locations" via Terraform — blocked wrong region. RCAs: sync deny vs async compliance reporting, and Terraform-blocked RG delete from out-of-band `az` resources. Teardown done. |
| 2026-07-07 | Lab 04 | Security & Identity | ✅ Completed | ~1h | Managed identity + RBAC Key Vault + keys-disabled storage via Bicep. Fixed the Lab 2 gaps: reproduced Key Vault Forbidden then granted a data-plane role (Secrets Officer); proved storage keys disabled, accessed blobs via Azure AD. Managed identity confirmed as a least-privilege service principal. RCA: RBAC propagation delay. Teardown done. |
| 2026-07-07 | Lab 05 | Secrets, Encryption & Network Security | ✅ Completed | ~1.5h | Disabled public network access on storage + Key Vault (confirmed public path blocked), created a Private Endpoint (private IP 10.30.1.4), and wired Private DNS (zone + VNet link + zone group). Mastered the CNAME→privatelink→private-IP resolution flow. RCA: missing-DNS is the #1 PE failure. Teardown done. |
| 2026-07-08 | Monitoring | Monitoring & Observability | ✅ Completed | ~1h | Log Analytics workspace + storage + diagnostic setting via Bicep. Read near-real-time metrics (Transactions/Availability), Activity Log audit trail, KQL over AzureMetrics (where/project/summarize), and created a metric alert. RCA: log ingestion latency (~5–15 min) vs instant metrics API. Teardown done. |

<!-- Template row:
| YYYY-MM-DD | Lab 0X | <skill> | ✅ Completed / ⚠️ Partial | Xh | one-line takeaway |
-->
