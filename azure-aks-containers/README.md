# Kubernetes on Azure — Containerized App on AKS

**Domain:** Containers & orchestration · **Stack:** AKS · ACR · Docker · Helm · GitHub Actions · Managed Identity · **Goal:** build, ship, and run a containerized app on Kubernetes the way a cloud engineer does

## Objective

Containers and AKS appear in a large share of Azure Cloud Engineer postings — and this is the one skill the rest of the portfolio didn't cover. This project closes it end to end:

- Get an image into **Azure Container Registry (ACR)** without a build agent.
- Keep app config **outside the image** with a Kubernetes **ConfigMap**.
- Run a real **AKS cluster** with a **managed identity**, attached to ACR so pulls are **passwordless** (your identity skills, applied to Kubernetes).
- Deploy with a **Helm chart** — templated, versioned, repeatable.
- **Scale**, prove **self-healing**, and read logs with `kubectl`.
- Author a **GitHub Actions** pipeline that builds and deploys on every push.

## ⚠️ Read this first — cost and quota

This is the **only project in the portfolio that meaningfully costs money.**

- The AKS **control plane is free**; the **worker node bills by the hour** (~$0.09/hr for `Standard_D2als_v7`).
- A **LoadBalancer** public IP and **ACR Basic** add a few cents.
- Finish and **tear down in the same session.** Expect well under $2 if you do.
- **Student subscriptions restrict VM sizes.** The burstable B-series is denied by policy. See Part A.

Set a mental timer. Part F is not optional.

## Prerequisites

- Azure Cloud Shell (**bash**) — it already has `az`, `kubectl`, and `helm`.
- Owner on the subscription.
- Files under `~/aks` (see `bootstrap-aks.sh`).

---

## Part A — Create the registry and the cluster (≈15 min)

Register the providers (first time only, takes a minute):

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.ContainerRegistry
```

Create the resource group and a **globally unique** ACR:

```bash
RG=aks-rg
LOC=eastus
ACR=aksacr$RANDOM
az group create -n $RG -l $LOC
az acr create -g $RG -n $ACR --sku Basic
echo "ACR: $ACR"
```

Create a **single-node** AKS cluster with a managed identity, and **attach ACR** so the cluster can pull images without any password:

```bash
az aks create -g $RG -n aks-lab \
  --node-count 1 \
  --node-vm-size Standard_D2als_v7 \
  --enable-managed-identity \
  --attach-acr $ACR \
  --generate-ssh-keys \
  --no-wait
```

> `--no-wait` returns immediately. Watch it finish:
> ```bash
> az aks show -g $RG -n aks-lab --query provisioningState -o tsv
> ```
> Repeat until it says `Succeeded` (usually 3–6 minutes).

> **RCA — why not `Standard_B2s`?** On a student subscription it fails with
> `(BadRequest) The VM size of Standard_B2s is not allowed in your subscription`.
> That is **not a quota error** — it's an *allowed-SKUs Azure Policy* denying the
> whole burstable B-series at create time. The same deny mechanism you built in the
> governance project, seen from the receiving end. The error lists the permitted
> sizes; `Standard_D2als_v7` is the smallest. Fallbacks: `Standard_D2as_v7`, `Standard_D2s_v7`.

Now point `kubectl` at the cluster and confirm the node is ready:

```bash
az aks get-credentials -g $RG -n aks-lab --overwrite-existing
kubectl get nodes -o wide
```

You should see one node with status `Ready`. **That's a live Kubernetes cluster.**

---

## Part B — Get the image into ACR (≈5 min)

The obvious move is `az acr build`, which ships your Dockerfile to ACR and builds it there. On this subscription it fails:

```
(TasksOperationsNotAllowed) ACR Tasks requests for the registry ... are not permitted.
```

**ACR Tasks is disabled**, and Cloud Shell has **no Docker daemon**, so there's no local build either. The way through is `az acr import` — a registry-side copy of an existing image, no build service involved:

```bash
az acr import -n $ACR --source docker.io/library/nginx:alpine --image portfolio-app:v1
az acr repository show-tags -n $ACR --repository portfolio-app -o table
```

Custom content then goes in via a **ConfigMap** mounted into the container, rather than baked into the image. That's not a consolation prize — it's the pattern real teams use: config lives outside the image, so the *same* image runs in dev, staging, and prod.

> On a subscription where ACR Tasks is available, `cd ~/aks/app && az acr build -r $ACR -t portfolio-app:v1 .` builds the included `Dockerfile` and the rest of this project is unchanged.

---

## Part C — Deploy with Helm (≈10 min)

Helm is a package manager for Kubernetes. The chart is a **template**; `values.yaml` holds the parameters — the same idea as Bicep params or Terraform variables.

Preview the rendered YAML *before* you install (your preview-first habit, applied to Kubernetes):

```bash
cd ~/aks
helm template portfolio ./helm/portfolio-app \
  --set image.repository=$ACR.azurecr.io/portfolio-app \
  --set image.tag=v1
```

Now install it:

```bash
helm upgrade --install portfolio ./helm/portfolio-app \
  --set image.repository=$ACR.azurecr.io/portfolio-app \
  --set image.tag=v1
```

Watch the pods come up, then wait for the public IP:

```bash
kubectl get pods -w        # Ctrl+C once both show Running
kubectl get svc portfolio  # re-run until EXTERNAL-IP is not <pending>
```

Open that `EXTERNAL-IP` in a browser. **Your container is serving traffic from Kubernetes.**

> Notice: no registry password anywhere. The cluster's **managed identity** pulls from ACR because you attached it in Part A.

---

## Part D — Scale, self-heal, and observe (≈10 min)

**Scale up.** Kubernetes reconciles to whatever you declare:

```bash
kubectl scale deployment portfolio --replicas=4
kubectl get pods
```

**Prove self-healing.** Delete a pod and watch Kubernetes rebuild it — you never asked it to:

```bash
kubectl delete pod $(kubectl get pods -l app=portfolio -o jsonpath='{.items[0].metadata.name}')
kubectl get pods          # one is Terminating, a new one is already Creating
```

That's the core idea of Kubernetes: you declare desired state, the controller makes reality match. Same reconcile loop as `terraform apply` or a Bicep deployment — just running continuously.

**Read logs and inspect:**

```bash
kubectl logs -l app=portfolio --tail=20
kubectl describe deployment portfolio | head -30
helm list
```

Scale back down before moving on:

```bash
kubectl scale deployment portfolio --replicas=2
```

---

## Part E — CI/CD to Kubernetes (reference)

`.github/workflows/aks-deploy.yml` shows the production pattern: on every push, build the image in ACR, then `helm upgrade --install` against the cluster.

Running it live needs a service principal or OIDC federated credential, which a **student tenant blocks** (`az ad sp create-for-rbac` → *Insufficient privileges*). That's the same wall you hit in the DevOps project. The workflow is committed as a **reference implementation** — you can read it, explain it, and run it on any subscription where you can create an app registration.

The shape worth remembering: **build the image → push to registry → `helm upgrade --install` → verify rollout**, with an approval gate before production.

---

## Part F — Teardown (do not skip)

```bash
helm uninstall portfolio
az group delete -n aks-rg --yes
az group list --query "[?starts_with(name,'aks')].name" -o tsv
```

The last command should print **nothing**.

> Deleting the resource group removes the cluster, the node, the load balancer IP, and the registry together. `helm uninstall` first is good hygiene — it releases the public IP cleanly.

Double-check nothing lingers:

```bash
az aks list -o table
az acr list -o table
```

---

## Success criteria ✅

- [ ] Got an image into a private ACR without a build agent (`az acr import`)
- [ ] Ran a live AKS cluster with a managed identity, ACR attached for passwordless pulls
- [ ] Deployed with a Helm chart and reached the app on a public IP
- [ ] Scaled replicas and watched Kubernetes self-heal a deleted pod
- [ ] Can explain the reconcile loop, Services/selectors, probes, requests vs limits, and Running vs Ready
- [ ] Cleaned up — `az aks list` is empty

## How to talk about it (interview)

> "I ran a containerized app on AKS, deployed with a Helm chart. The cluster used a managed identity attached to ACR, so image pulls were passwordless — no registry secret anywhere in the chart. App config lived in a ConfigMap rather than baked into the image, so one image runs in every environment. I set resource requests and limits plus liveness and readiness probes, scaled the deployment, and verified self-healing by deleting a pod and watching the controller replace it in about a second. The CI/CD path is build image → push → `helm upgrade --install` → verify rollout, behind an approval gate."

> On constraints: "Two platform restrictions blocked the happy path — an allowed-SKUs policy denied the B-series VM sizes, and ACR Tasks was disabled. I read the errors, distinguished a policy deny from a quota limit, and routed around both with `az acr import` and a ConfigMap without giving up the security posture."

## Reflection questions

1. What is the reconcile loop, and how is it like — and unlike — `terraform apply`?
2. A pod is `Running` but getting no traffic. What do you check first? (Hint: `0/1` vs `1/1`.)
3. Why do requests and limits matter? What happens if you omit them?
4. How does the cluster pull from ACR without a password?
5. When would you choose `ClusterIP` over `LoadBalancer`?

---

**Cost reminder:** if you stopped partway through, run Part F now. An idle AKS node bills around the clock.
