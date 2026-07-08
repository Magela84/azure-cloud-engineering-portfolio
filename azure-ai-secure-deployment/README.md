# Secure AI Deployment on Azure (Azure OpenAI / AI Services)

**Domain:** AI on Azure (cloud-engineer side) · **Stack:** Azure AI Services · Bicep · Managed Identity · RBAC · Log Analytics · **Goal:** deploy and run AI services securely and cost-consciously

## Objective

The AI skill employers want from a **cloud engineer** isn't training models — it's **deploying, securing, monitoring, and cost-controlling AI services.** This project does exactly that, reusing everything you've built:

- Deploy an **Azure AI Services** account with **Bicep**.
- Turn **API keys off** so access is **Azure AD only** (your identity skills).
- Give it a **managed identity** (passwordless).
- Stream its **logs and metrics to Log Analytics** (your monitoring skills).
- Know the **cost** model (tokens) and how to lock it to a **private network**.

## Why this matters

AI services are powerful and expensive, and often handle sensitive data — so they must be deployed carefully: no leaked keys, private networking, monitored usage, controlled cost. That's a cloud engineer's job, and there's a large talent shortage for exactly this. It's the highest-leverage skill to add on top of what you already have.

## Prerequisites

- Prior projects done; Azure Cloud Shell (**bash**); Owner on the subscription.
- Files under `~/azai`.
- Note: full **Azure OpenAI** (deploying and calling a GPT model) can require access approval and may be limited on a student subscription. This project focuses on the part that's always valuable — **deploying and securing the AI service** — which is identical whether the models come later or not.

---

## Part A — Deploy the AI service, secured (≈15 min)

```bash
az group create -n azai-rg -l eastus
cd ~/azai/bicep
az deployment group create -g azai-rg --name azai --template-file main.bicep
```
Capture the outputs:
```bash
RG=azai-rg
AI=$(az deployment group show -g $RG -n azai --query properties.outputs.aiAccountName.value -o tsv)
echo "AI account: $AI"
```

> If the deploy errors about terms or the `AIServices` kind, redeploy with `--parameters aiKind=CognitiveServices` — the secure pattern is identical.

---

## Part B — Prove it's secured (no keys, AAD only) (≈10 min)

Check the security posture on the live resource:
```bash
az cognitiveservices account show -n "$AI" -g $RG \
  --query "{localAuthDisabled:properties.disableLocalAuth, publicAccess:properties.publicNetworkAccess, identity:identity.type}" -o jsonc
```
Expected: `localAuthDisabled: true` (API keys are off), a system-assigned `identity`, and public access shown. Because keys are disabled, the *only* way to call this service is with an Azure AD identity — no secret to leak.

Prove the key path is dead:
```bash
az cognitiveservices account keys list -n "$AI" -g $RG
```
Expected: an error / refusal — local (key) auth is disabled. This is the AI equivalent of the keys-disabled storage from your security project.

---

## Part C — Grant Azure AD access to use it (≈10 min)

With keys off, you reach the service with a data-plane role — same pattern as Key Vault/storage.
```bash
ME=$(az ad signed-in-user show --query id -o tsv)
AIID=$(az cognitiveservices account show -n "$AI" -g $RG --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Cognitive Services User" --scope "$AIID"
```
Now your Azure AD identity can call the service's data plane (once models are deployed). No keys anywhere — exactly how you'd wire an app's **managed identity** to use AI.

---

## Part D — Monitoring & cost awareness (≈10 min)

The diagnostic setting already streams the AI service's logs/metrics to Log Analytics. View the account's metrics:
```bash
az monitor metrics list --resource "$AIID" --metric TotalCalls --aggregation Total -o table 2>/dev/null || echo "(no calls yet)"
```

**Cost mindset (the FinOps angle for AI):**
- AI is billed per **token** (roughly, per word) — it can get expensive *fast* under load.
- Control it with: a **budget + alert** (your FinOps project), **monitoring token usage** in Log Analytics, choosing the **right model** (smaller/cheaper where it fits), and **rate limits/quotas** on deployments.
- Tag the resource with a cost center so its spend is attributable.

---

## Part E — Private networking (production posture) (concept + optional)

For production you'd remove public exposure entirely — exactly like your private-endpoints project:
```bash
# Lock it to private-only:
az cognitiveservices account update -n "$AI" -g $RG --custom-domain "$(az cognitiveservices account show -n "$AI" -g $RG --query properties.customSubDomainName -o tsv)" --api-properties '{}' 2>/dev/null || true
# (Set publicNetworkAccess=Disabled, then add a Private Endpoint + private DNS zone
#  privatelink.cognitiveservices.azure.com — same steps as azure-private-endpoints.)
```
The pattern is identical to your storage/Key Vault private endpoints: disable public access, add a private endpoint in your VNet, wire the private DNS zone. AI services support this fully.

---

## Part F — Teardown

```bash
az role assignment delete --assignee-object-id "$ME" --role "Cognitive Services User" --scope "$AIID" 2>/dev/null || true
az group delete -n azai-rg --yes
az group list --query "[?starts_with(name,'azai')].name" -o tsv
```
> Cognitive Services accounts soft-delete. If you redeploy the same name later and hit a conflict, purge it: `az cognitiveservices account purge -n <name> -g <rg> -l <location>`.

---

## Success criteria ✅

- [ ] Deployed an Azure AI Services account via Bicep
- [ ] Confirmed keys are disabled (Azure AD-only) and it has a managed identity
- [ ] Granted an Azure AD data-plane role (Cognitive Services User)
- [ ] Logs/metrics flowing to Log Analytics
- [ ] Can explain AI cost control (tokens, budgets, quotas) and private-networking the service
- [ ] Cleaned up

## How to talk about it (interview)

"I deploy AI services the secure way: infrastructure as code, API keys disabled so it's Azure AD-only, a managed identity for passwordless access, private networking, and usage streamed to Log Analytics with a budget on top for token cost. It's the same security and operations discipline I apply to any Azure resource, applied to AI."

## Reflection questions

1. Why disable API keys on an AI service and use Azure AD instead?
2. Why is cost control especially important for AI workloads?
3. How would you make this AI service reachable only from inside your network?

---

Paste outputs as you go — I'll document it, and this adds the most in-demand skill to your portfolio.
