# DevOps / CI-CD — Notes & Documentation

> Trainer-maintained log.

**Date:** ______  **Where it runs:** GitHub Actions (not Cloud Shell)

## What this project is
An automated pipeline (GitHub Actions) that validates infrastructure on every push. Unlike the other projects, this one runs in GitHub's cloud, not in Azure Cloud Shell — so the "hands-on" is: push the workflow, then watch it run in the repo's Actions tab.

## Session log
- Added `.github/workflows/validate-iac.yml` (live CI) + `azure-devops-cicd/` project (README, sample bicep, workflow copies, CD example).
- Pushed from local machine; workflow triggered automatically.
- Actions tab result: **green check** — Bicep compiled and Terraform validated successfully in GitHub Actions.
- Push gotcha: first push was rejected — "refusing to allow an OAuth App to create/update workflow without workflow scope." Cause: the cached GitHub credential lacked the `workflow` permission. Fix: used a Personal Access Token (repo + workflow scopes) in the remote URL. (Security note: rotate any token that gets exposed.)

## How the CI works
1. Push a change → GitHub starts the workflow on a fresh Linux runner.
2. Job 1 compiles the Bicep templates (az bicep build) — catches syntax errors.
3. Job 2 runs terraform init -backend=false + validate.
4. Green check = all good; red X = something to fix, with the exact error.

## CD (deploy with approval) — reference only
- `workflows/deploy-with-approval.example.yml` shows preview (what-if) → approval gate (GitHub Environment "production" with a required reviewer) → deploy.
- Needs Azure credentials (OIDC app registration or service principal) + repo secrets.
- **Attempted the connection:** `az ad sp create-for-rbac` → BLOCKED with "Insufficient privileges to complete the operation. Directory permission is needed for the current user to register the application." The franklin.edu student tenant restricts app registration to admins.
- **Outcome:** CI (validate) is fully live; CD (deploy) is documented and understood, but live credentials require a directory admin or a non-restricted Azure account. This is a normal real-world tenant constraint, not a skills gap.
- **Interview line:** "I built a CI pipeline that validates infrastructure on every commit and authored the CD pipeline with preview + approval; wiring live deploy credentials just needed directory permissions my student tenant restricts."

## Key takeaways
- CI = check every change automatically; CD = deploy, ideally behind preview + approval.
- Compiling/validating on every push catches errors before they reach Azure.
- The approval gate (Environment reviewer) is a human sign-off before production changes.
- Secrets live in GitHub secrets, never in the workflow file.
- A "runner" is the temporary cloud machine that runs the workflow.

## RCA / gotchas
- Workflow only runs if the file is at `.github/workflows/*.yml` in the repo root.
- CI needs no Azure login (compile/validate are local to the runner); only CD needs credentials.
