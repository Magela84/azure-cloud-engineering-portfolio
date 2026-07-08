# Secure AI Deployment — Notes

> Trainer-maintained log.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. The AI skill — secure AI deployment (cloud-engineer side).

## Part A — Deploy the AI service
- `az deployment group create` → **Succeeded** (26s). AIServices account `azai-5owsf-ai` + Log Analytics + diagnostic setting. Deployed on the student sub with no OpenAI-style approval needed.
- Endpoint: https://azai5owsf.cognitiveservices.azure.com/  · System-assigned identity principalId ed57628e-... · aiKind = AIServices.

## Part B — Security posture
- `account show` → `localAuthDisabled: true`, `identity: SystemAssigned`, `publicAccess: Enabled`. Confirmed keys-off + managed identity.
- `keys list` → **BadRequest: "Failed to list key. disableLocalAuth is set to be true."** Proof the API-key path is dead — Azure AD is the only way in. (AI equivalent of keys-disabled storage.)

## Part C — Azure AD access
- `role assignment create` → **Succeeded.** `Cognitive Services User` (roleDef a97b65f3-...) granted to my user (principalId ade31683-...) at the AI account scope. No student-tenant block this time. This is the data-plane role an app's managed identity would hold — passwordless AI access.

## Part D — Monitoring & cost
- `diagnostic-settings list` → `ai-to-law` streaming to workspace `azai-law`. Confirmed telemetry wired.
- `metrics list --metric TotalCalls` → clean data, all `0.0` (no model calls yet — expected). Monitoring plumbing works.
- Cost mindset: AI bills per **token** (per word), so cost scales with usage not time — a runaway app spikes fast. Controls: budget+alert (FinOps), watch token usage in Log Analytics, smallest model that fits, rate limits/quotas per deployment, cost-center tag.

## Part E — Private networking
- Concept / steps noted:

## Reflection answers
1.
2.
3.

## Teardown confirmation
- [x] Role assignment removed
- [x] Resource group deleted (`az group delete -n azai-rg --yes`)
- [x] `az group list` for azai* → **empty** (confirmed gone)
- [ ] Account purge only needed if redeploying the same name later (soft-delete)
