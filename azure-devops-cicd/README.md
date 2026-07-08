# CI/CD Pipeline — GitHub Actions for Infrastructure

**Domain:** DevOps / CI-CD · **Stack:** GitHub Actions · Azure CLI · Bicep · Terraform · **Goal:** automatically check (and optionally deploy) infrastructure on every change

## Objective

Turn manual deployments into an automated pipeline. Instead of running deploy commands by hand, a workflow runs automatically whenever code changes:

- **Continuous Integration (CI)** — on every push and pull request, it **compiles the Bicep** and **validates the Terraform**. If a template has an error, the build turns red *before* it can ever reach Azure.
- **Continuous Deployment (CD)** — an example workflow that **deploys** the infrastructure, but only after a human **approves** it (an approval gate).

## Why this matters

This is the practice that ties every other project together. Your IaC is only as safe as your process for shipping it. A pipeline catches mistakes early, forces a preview and an approval before production changes, and gives you a permanent record of every deployment. It completes the loop: write code → automatically check it → approve → deploy.

## What's in this repo

- **`.github/workflows/validate-iac.yml`** (at the repo root) — the **live** CI pipeline. GitHub runs it automatically. It compiles the Bicep templates and validates the Terraform.
- **`workflows/validate-iac.yml`** — a copy of that live workflow, here for easy viewing.
- **`workflows/deploy-with-approval.example.yml`** — a reference CD pipeline showing the deploy-with-approval pattern (not active; needs Azure credentials — see below).
- **`bicep/main.bicep`** — a small clean template the CI compiles.

## How the CI pipeline works (plain English)

1. You change a file and push it to GitHub.
2. GitHub notices and starts the workflow automatically — a fresh Linux machine spins up in the cloud.
3. That machine installs Bicep, then tries to **compile** each template. Compiling catches syntax errors.
4. It also **initializes and validates** the Terraform.
5. If everything's good, you get a **green check** next to your commit. If something's broken, a **red X** — and it tells you exactly what failed, so you fix it before it causes harm.

No Azure account or credentials are needed for this — compiling and validating happen entirely on the GitHub machine.

## See it run

1. Push this repo (or any change) to GitHub.
2. On your repo page, click the **Actions** tab at the top.
3. You'll see the **"Validate Infrastructure"** workflow running (a yellow dot), then finishing (green check or red X).
4. Click into a run to see each step's output — the Bicep compiling, the Terraform validating.

You can also start it by hand: Actions tab → "Validate Infrastructure" → **Run workflow**.

## Adding real deployment (the CD half)

`workflows/deploy-with-approval.example.yml` shows how you'd deploy automatically with a safety gate:

- A **preview** job runs `what-if` to show what would change.
- A **deploy** job runs only after a reviewer approves it, using a GitHub **Environment** called `production` with a required reviewer.

To make it live you'd:

1. Give GitHub permission to deploy to Azure — create an app registration with a **federated credential (OIDC)** or a service principal.
2. Add repo secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
3. Create a GitHub **Environment** named `production` and add yourself as a **required reviewer** — that approval is the gate.

Heads-up: some school or work Azure tenants block creating app registrations, so this step may need an administrator. The CI (validate) workflow needs none of this and works for everyone.

## Key concepts

- **CI (Continuous Integration):** automatically check every change. Catches errors early.
- **CD (Continuous Deployment):** automatically deploy — ideally behind a preview and an approval.
- **Workflow:** the recipe (a YAML file) telling GitHub what to run and when.
- **Approval gate:** a required human sign-off before a deployment proceeds (a GitHub Environment reviewer).
- **Runner:** the temporary cloud machine GitHub spins up to run your workflow.

## Reflection questions

1. Why is it valuable to compile/validate on every push instead of only when you deploy?
2. What does the approval gate protect you from?
3. Why keep secrets in GitHub secrets rather than in the workflow file?
