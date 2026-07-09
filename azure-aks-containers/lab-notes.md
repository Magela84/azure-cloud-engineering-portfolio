# Kubernetes on AKS — Notes

> Trainer-maintained log.

**Date:** ______  **Environment:** Azure Cloud Shell (bash)  **Region:** eastus

**⚠️ Cost note:** this is the only project that meaningfully bills. Node + LoadBalancer IP + ACR.
Teardown must happen in the same session.

## Part A — Registry & cluster
- ACR: `aksacr14947` (Basic), loginServer `aksacr14947.azurecr.io`. `adminUserEnabled: false` — no admin password.
- **RCA — VM size denied:** `az aks create --node-vm-size Standard_B2s` → `(BadRequest) The VM size of Standard_B2s is not allowed in your subscription in location 'eastus'.` **Not a quota error** — an allowed-SKUs *Azure Policy* on the student subscription blocks the whole B-series (burstable). Deny-at-create, exactly like the custom policy I wrote in project 03, seen from the other side. Fix: pick from the allowed list → `Standard_D2als_v7` (smallest allowed, 2 vCPU AMD).
- `az aks create --node-vm-size Standard_D2als_v7` → **Succeeded.** K8s 1.35.5, 1 node, SKU tier Free (control plane free).
- Identity: `SystemAssigned` (principalId a212f8d9-…); kubelet identity `aks-lab-agentpool`. `AAD role propagation done` = ACR attach granted **AcrPull** → passwordless image pulls.
- Node resource group: `MC_aks-rg_aks-lab_eastus` (Azure-managed; holds the node VMSS + LB public IP).
- `kubectl get nodes`:

## Part B — Getting the image into ACR
- **RCA — ACR Tasks blocked:** `az acr build` → `(TasksOperationsNotAllowed) ACR Tasks requests for the registry ... are not permitted.` Student subscription disables ACR Tasks (cloud builds). Cloud Shell has no Docker daemon, so no local build either.
- **Workaround:** `az acr import` — a registry-side copy of a public image, no build service required. Custom content then injected via a Kubernetes **ConfigMap** mounted into the container, keeping config out of the image (the more production-realistic pattern regardless).
- `az acr import --source docker.io/library/nginx:alpine --image portfolio-app:v1` → **Succeeded**; `show-tags` → `v1`.
- **Paste hazard:** the long heredoc for `deployment.yaml` was mangled by Cloud Shell (newlines dropped mid-heredoc). Fixed by restoring the file from a single-line `base64 -d` command — no newlines for the terminal to lose. Worth remembering for any long paste.

## Part C — Helm deploy
- `helm lint` → 0 failed. `helm template` preview rendered ConfigMap + Service + Deployment correctly (previewed before installing — same habit as what-if / plan).
- `helm upgrade --install portfolio` → **STATUS: deployed, REVISION: 1**.
- Pods: `portfolio-6cbf86ffc-4mpmz` and `-pnzt7`, both **1/1 Running** (1/1 = container up AND readiness probe passing → Service puts it in rotation).
- Service: LoadBalancer, CLUSTER-IP 10.0.146.168, **EXTERNAL-IP 20.241.175.253**. `curl` returned the page. ✅
- **No `imagePullSecret` anywhere** — image pulled from private ACR via the cluster's managed identity (AcrPull). Passwordless, end to end.

## Part D — Scale & self-heal
- `kubectl scale --replicas=4` → 2 existing Running, 2 new in **Pending** (scheduler placing them; Pending = no node has accepted the pod yet — with resource `requests` set, the scheduler is doing capacity math).
- **Self-healing proven:** deleted `portfolio-6cbf86ffc-4mpmz`; without being asked, a replacement `-7n899` appeared at **age 1s** and the count returned to 4. That's the **reconcile loop** — a controller observes actual state, compares to desired (`replicas: 4`), and acts. Continuously, unlike `terraform apply` which reconciles only when run.
- **`0/1 Running` vs `1/1 Running`:** the new pod showed `0/1 Running` — container up, readiness probe not yet passing (`initialDelaySeconds: 2`), so the Service withholds traffic from it. **Running ≠ Ready.** This is the first thing to check when "the pod is Running but users get errors."

## Part E — CI/CD (reference)
- Workflow reviewed; SP/OIDC blocked on student tenant (same as DevOps project):

## Reflection answers
1. **Reconcile loop vs terraform apply:** a controller continuously observes actual state, compares it to declared desired state, and acts to close the gap. `terraform apply` does the same comparison, but only once, when I run it. Kubernetes never stops — which is why a deleted pod comes back in a second without me doing anything.
2. **Pod Running but no traffic:** check `READY`. `0/1 Running` means the container is up but the **readiness probe** hasn't passed, so the Service withholds traffic. Running ≠ Ready. Next: does the Service `selector` match the pod `labels`? A mismatch there sends traffic nowhere.
3. **Requests vs limits:** requests are what the scheduler reserves when placing the pod (affects whether it can be scheduled at all — hence `Pending`); limits are the hard ceiling at runtime. Omit them and one noisy pod can starve the node.
4. **Passwordless ACR pull:** `--attach-acr` grants the cluster's kubelet managed identity the **AcrPull** role on the registry. No `imagePullSecret`, no registry password anywhere in the chart.
5. **ClusterIP vs LoadBalancer:** ClusterIP is internal-only (reach it with `kubectl port-forward`) — right for internal services and cheaper, no public IP. LoadBalancer provisions an Azure public IP and is for things that must be reachable from the internet.

## Teardown confirmation
- [x] `helm uninstall portfolio` (released the public IP cleanly)
- [x] `az group delete -n aks-rg --yes`
- [x] `az group list` for aks* → **empty**
- [x] `az group list` for MC_aks* → **empty** (Azure removed the managed node RG too)
- [x] `az aks list -o table` → **empty**
- [x] `az acr list -o table` → **empty**
- Total runtime ~25 min on one `Standard_D2als_v7` node. Nothing left billing.

## Errors / RCA
1. **`Standard_B2s is not allowed in your subscription`** — *not* a quota error. An allowed-SKUs Azure Policy on the student subscription denies the whole burstable B-series. Deny-at-create, same mechanism as the custom policy in project 03, experienced from the receiving end. Fix: chose `Standard_D2als_v7` from the error's allowed list.
2. **`TasksOperationsNotAllowed`** — ACR Tasks (cloud image builds) disabled on the subscription, so `az acr build` fails; Cloud Shell has no Docker daemon either. Fix: `az acr import` copies a public image registry-side (no build service), and custom content is injected via a **ConfigMap** mounted into the container. Arguably better practice anyway — config lives outside the image, so one image runs in every environment.
3. **Cloud Shell mangled a long heredoc paste** (newlines dropped mid-block), corrupting `deployment.yaml`. Fix: restore the file with a single-line `echo '<base64>' | base64 -d > file` — no newlines for the terminal to lose. Reusable trick for any long paste.
