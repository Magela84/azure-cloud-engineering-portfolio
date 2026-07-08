#!/usr/bin/env bash
# PowerShell/CLI/Automation bootstrap for Azure Cloud Shell — creates ~/azauto.
mkdir -p ~/azauto/scripts && cd ~/azauto

cat > scripts/cloud-report.sh <<'EOF'
#!/usr/bin/env bash
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
echo "-- Stopped (deallocated) VMs — cost candidates --"
az vm list -d --query "[?powerState=='VM deallocated'].{name:name, group:resourceGroup}" -o table || echo "(none)"
echo ""
echo "-- Resources missing an 'owner' tag --"
az resource list --query "[?tags.owner==null].{name:name, type:type, group:resourceGroup}" -o table
echo ""
echo "Report complete."
EOF

cat > scripts/cloud-report.ps1 <<'EOF'
Write-Output "==================================================="
Write-Output " Azure Cloud Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Output "==================================================="
$ctx = Get-AzContext
Write-Output "Subscription: $($ctx.Subscription.Name)"
Write-Output ""
$groups = Get-AzResourceGroup
Write-Output "Resource groups: $($groups.Count)"
Write-Output ""
Write-Output "Resources by type (top 15):"
Get-AzResource | Group-Object ResourceType | Sort-Object Count -Descending |
  Select-Object -First 15 Count, Name | Format-Table -AutoSize
Write-Output "Resources missing an 'owner' tag:"
Get-AzResource | Where-Object { -not $_.Tags -or -not $_.Tags.ContainsKey('owner') } |
  Select-Object Name, ResourceType, ResourceGroupName | Format-Table -AutoSize
Write-Output "Report complete."
EOF

echo "=== files created in ~/azauto ==="
find . -type f | sort
