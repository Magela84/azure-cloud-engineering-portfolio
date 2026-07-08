# Private-Only Networking — Private Endpoints & DNS

**Domain:** Network Security · **Stack:** Azure VNet · Private Endpoints · Private DNS · Bicep · **Goal:** remove public exposure from Storage & Key Vault

## Objective

Take data services that are reachable over the public internet and lock them down to **private-only** access:

- **Disable public network access** on storage and Key Vault.
- Add a **Private Endpoint** — a private IP inside your VNet that maps to the service.
- Wire up **Private DNS** so the service's normal hostname resolves to that private IP from inside the VNet.
- Understand the **DNS mechanics** that make private endpoints actually work (this is where most people get stuck).

## Why this matters

`allowSharedKeyAccess: false` (Lab 4) secured *authentication*. This lab secures the *network path*: even with a valid token, you can't reach the data unless you're coming through the private endpoint. Public access disabled + Private Endpoint is the gold-standard posture for storage, Key Vault, SQL, and most PaaS data services.

## Key concepts (quick)

- **Private Endpoint (PE):** a network interface with a private IP in your subnet that connects privately to one specific service (a "group" like `blob` or `vault`).
- **Private DNS zone:** e.g. `privatelink.blob.core.windows.net` — overrides the service's public DNS so its hostname resolves to the PE's private IP *inside your VNet*.
- **The DNS trick:** public DNS for `mysa.blob.core.windows.net` returns a CNAME to `mysa.privatelink.blob.core.windows.net`. Without the private zone that still resolves to a public IP; *with* the linked private zone, it resolves to the PE's private IP. That linkage is what makes PEs work — and forgetting it is the #1 PE failure.

## Prerequisites

- Labs 1–4 done; Azure Cloud Shell (**bash**); Owner + User Access Administrator.
- Files under `~/lab05`.

---

## Part A — Deploy the base (≈10 min)

```bash
az group create -n azlab05-rg -l eastus
cd ~/lab05/bicep
az deployment group create -g azlab05-rg --name lab05 --template-file main.bicep
```
Capture names:
```bash
RG=azlab05-rg
SA=$(az deployment group show -g $RG -n lab05 --query properties.outputs.storageAccountName.value -o tsv)
KV=$(az deployment group show -g $RG -n lab05 --query properties.outputs.keyVaultName.value -o tsv)
echo "SA=$SA  KV=$KV"
```

---

## Part B — See it's public, then disable public access (≈15 min)

**1. Confirm it's currently public:**
```bash
az storage account show -n "$SA" --query "{publicAccess:publicNetworkAccess, defaultAction:networkRuleSet.defaultAction}" -o jsonc
```
Expect `publicAccess: Enabled`.

**2. Lock it down — disable public network access on both services:**
```bash
az storage account update -n "$SA" --public-network-access Disabled --default-action Deny
az keyvault update -n "$KV" --public-network-access Disabled
```

**3. Prove the public path is now closed.** From Cloud Shell (which is *outside* your VNet), try to touch the data:
```bash
az storage container list --account-name "$SA" --auth-mode login -o table
```
Expect a network/authorization failure — public access is gone, and Cloud Shell isn't inside the VNet. The service is now unreachable except through a private endpoint.

---

## Part C — Add a Private Endpoint for the blob service (≈25 min)

**1. Grab the IDs you'll need:**
```bash
SAID=$(az storage account show -n "$SA" --query id -o tsv)
```

**2. Create the private endpoint in the pe-subnet, targeting the `blob` sub-resource:**
```bash
az network private-endpoint create \
  --name azlab05-blob-pe -g $RG \
  --vnet-name azlab05-vnet --subnet pe-subnet \
  --private-connection-resource-id "$SAID" \
  --group-id blob \
  --connection-name azlab05-blob-conn
```

**3. See the private IP it was given** (a 10.30.1.x address inside your subnet):
```bash
az network private-endpoint show -g $RG -n azlab05-blob-pe \
  --query "customDnsConfigs" -o jsonc
```
Note the private IP — that's your storage account, now reachable inside the VNet.

---

## Part D — Wire up Private DNS (the part everyone forgets) (≈20 min)

**1. Create the private DNS zone for blob storage:**
```bash
az network private-dns zone create -g $RG -n privatelink.blob.core.windows.net
```

**2. Link the zone to your VNet** (so VMs in the VNet use it for name resolution):
```bash
az network private-dns link vnet create -g $RG -n dnslink \
  --zone-name privatelink.blob.core.windows.net \
  --virtual-network azlab05-vnet --registration-enabled false
```

**3. Connect the endpoint to the zone** (this auto-creates the A record mapping your storage name → the PE's private IP):
```bash
az network private-endpoint dns-zone-group create -g $RG \
  --endpoint-name azlab05-blob-pe --name default \
  --private-dns-zone privatelink.blob.core.windows.net --zone-name blob
```

**4. See the A record it created** — proof of the private mapping:
```bash
az network private-dns record-set a list -g $RG \
  -z privatelink.blob.core.windows.net -o table
```
You'll see your storage account name mapped to the `10.30.1.x` private IP.

**5. Observe the public DNS side** from Cloud Shell:
```bash
nslookup $SA.blob.core.windows.net
```
Notice the answer is a **CNAME to `…privatelink.blob.core.windows.net`**. From Cloud Shell (no link to your private zone) that still resolves publicly — but a VM *inside your VNet* would resolve it to the `10.30.1.x` private IP via the zone you linked. That override is the whole mechanism.

---

## Part E — Break & Diagnose (RCA) (≈10 min)

**Scenario — "private endpoint exists but the app still can't connect / resolves to a public IP."**
- *Diagnose:* Is the **DNS zone group** attached to the PE (Part D step 3)? Is the zone **linked to the VNet** (step 2)? A PE with no DNS wiring gives you a private IP nothing resolves to.
- *Lesson:* A Private Endpoint is two halves — the **network interface** *and* the **DNS**. The IP alone does nothing; the private DNS zone (linked + zone group) is what makes the hostname resolve privately. Missing DNS is the number-one private-endpoint failure.

---

## Part F — Teardown

```bash
az group delete -n azlab05-rg --yes
az keyvault purge --name "$KV"    # use the literal KV name if the variable reset
az group list --query "[?starts_with(name,'azlab05')].name" -o tsv
```

---

## Success criteria ✅

- [ ] Deployed VNet + PE subnet + storage + Key Vault via Bicep
- [ ] Disabled public network access on both; confirmed the public path is closed
- [ ] Created a Private Endpoint and saw its private IP in the subnet
- [ ] Created + linked a Private DNS zone and attached the zone group (A record created)
- [ ] Can explain the CNAME → privatelink → private-IP resolution flow
- [ ] Understand that a PE needs BOTH a network interface and DNS wiring
- [ ] Everything torn down; vault purged

## Reflection questions

1. Why does a Private Endpoint need a Private DNS zone at all — what breaks without it?
2. What's the difference between `allowSharedKeyAccess: false` (Lab 4) and `publicNetworkAccess: Disabled` (this lab)? Which threat does each address?
3. How would a VM or app *inside* the VNet reach the storage account now, and how would something outside the VNet (legitimately) reach it?

---

Paste outputs as you go — I'll document it and wrap up the Security & Identity module.
