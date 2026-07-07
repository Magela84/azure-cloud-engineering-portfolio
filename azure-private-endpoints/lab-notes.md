# Lab 05 — Notes & Documentation

> Trainer-maintained log. Filled in as you paste outputs.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

## Session log
Azure Cloud Shell (bash), eastus. Continuation of the Security module (network hardening).

## Part A — Deploy base
- `az deployment group create` → **Succeeded** (21s). VNet + pe-subnet + storage + Key Vault (public access still Enabled).
- VNet `azlab05-vnet` (10.30.0.0/16, subnet pe-subnet 10.30.1.0/24), storage `azlab05yyxadsa`, Key Vault `azlab05-yyxad-kv`.

## Part B — Disable public access
- Before: storage publicNetworkAccess = Enabled, defaultAction = Allow.
- After: storage → publicNetworkAccess **Disabled**, defaultAction **Deny**; Key Vault → publicNetworkAccess **Disabled**.
- Public-path test from Cloud Shell (outside VNet): **BLOCKED** — "The request may be blocked by network rules of storage account." Public internet path closed; only a private endpoint can reach it now.

## Part C — Private Endpoint
- PE `azlab05-blob-pe` created in pe-subnet, group-id `blob`, connection Auto-Approved / Succeeded.
- Private IP assigned: **10.30.1.4** → mapped to azlab05yyxadsa.blob.core.windows.net. Storage now has a private address inside the VNet.

## Part D — Private DNS
- Zone `privatelink.blob.core.windows.net` created; linked to azlab05-vnet (registration disabled), link state Completed.
- DNS zone group attached to the PE → auto-created A record `azlab05yyxadsa` → **10.30.1.4** in the private zone.
- nslookup from Cloud Shell: `azlab05yyxadsa.blob.core.windows.net` CNAMEs to `...privatelink.blob.core.windows.net`, which (from OUTSIDE the VNet) resolves to a PUBLIC IP 52.239.169.100. A VM inside azlab05-vnet resolves the same name to the PRIVATE 10.30.1.4 via the linked zone.
- **DNS mechanism (key insight):** the public hostname always CNAMEs to the `privatelink` subdomain; whoever resolves that subdomain decides the answer. Linked-VNet → private IP; everyone else → public IP.

## Part E — RCA — "PE exists but app still hits the public IP"
- Symptom: private endpoint created, but connections still resolve to the public IP / fail.
- Root cause: missing or unlinked private DNS. A PE has TWO halves — the network interface (private IP) AND the private DNS zone (linked to the VNet + a zone group on the PE). The IP alone resolves to nothing useful.
- Lesson: always verify (1) the private DNS zone exists, (2) it's linked to the consuming VNet, (3) the PE has a dns-zone-group. Missing DNS is the #1 private-endpoint failure.

## Reflection answers
1.
2.
3.

## Teardown
- Deleted resource group `azlab05-rg` (VNet, private endpoint, private DNS zone + link, storage, Key Vault).
- Purged the soft-deleted Key Vault. Both verify lists returned empty. Environment clean.

## Lab 05 — Summary & outcome ✅
Locked internet-facing data services down to private-only networking. Deployed a VNet + private-endpoint subnet + storage + Key Vault, disabled public network access on both (confirmed the public path is closed), created a Private Endpoint giving storage a private IP inside the VNet, and wired up Private DNS so the hostname resolves privately. Mastered the DNS resolution flow that makes private endpoints work.

**Key takeaways**
- `publicNetworkAccess: Disabled` closes the network path — even a valid token can't reach the data from outside the VNet (complements Lab 4's auth hardening).
- A Private Endpoint = a private IP (network interface) in your subnet mapped to one service sub-resource (e.g. blob).
- The public hostname CNAMEs to `<name>.privatelink.<service>` — whoever resolves that subdomain decides the IP: a VNet linked to the private DNS zone gets the private IP; everyone else gets the public IP.
- A Private Endpoint needs BOTH halves: the network interface AND the private DNS (zone linked to the VNet + a dns-zone-group on the PE). Missing DNS is the #1 PE failure.
- Auth hardening (keys off, Lab 4) and network hardening (public access off + PE, Lab 5) are complementary layers — use both.
