#!/usr/bin/env bash
# =====================================================================
# Cloud estate report — a small automation using the Azure CLI.
# Summarizes your subscription: group count, resources by type,
# stopped VMs (cost candidates), and resources missing an owner tag.
# Run: bash cloud-report.sh
# Schedule it (cron, a pipeline, or an Azure Automation runbook) to get
# a regular health/cost snapshot with zero manual effort.
# =====================================================================
set -euo pipefail

echo "==================================================="
echo " Azure Cloud Report  —  $(date -u +'%Y-%m-%d %H:%M UTC')"
echo "==================================================="
echo "Subscription: $(az account show --query name -o tsv)"
echo ""

echo "-- Resource groups --"
echo "Total: $(az group list --query 'length(@)' -o tsv)"
echo ""

echo "-- Resources by type (top 15) --"
az resource list --query "[].type" -o tsv | sort | uniq -c | sort -rn | head -15
echo ""

echo "-- Stopped (deallocated) VMs — cost candidates to review --"
az vm list -d --query "[?powerState=='VM deallocated'].{name:name, group:resourceGroup}" -o table || echo "(none or no VM access)"
echo ""

echo "-- Resources missing an 'owner' tag --"
az resource list --query "[?tags.owner==null].{name:name, type:type, group:resourceGroup}" -o table
echo ""

echo "Report complete."
