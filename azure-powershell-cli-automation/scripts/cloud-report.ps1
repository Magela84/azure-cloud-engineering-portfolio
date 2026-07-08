# =====================================================================
# Cloud estate report — the same idea, written in Azure PowerShell (Az module).
# Shows the PowerShell way: objects and pipelines instead of text and JSON.
# Run in Cloud Shell's PowerShell mode (type: pwsh) — already signed in.
#   ./cloud-report.ps1
# =====================================================================

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
Get-AzResource |
  Group-Object ResourceType |
  Sort-Object Count -Descending |
  Select-Object -First 15 Count, Name |
  Format-Table -AutoSize

Write-Output "Resources missing an 'owner' tag:"
Get-AzResource |
  Where-Object { -not $_.Tags -or -not $_.Tags.ContainsKey('owner') } |
  Select-Object Name, ResourceType, ResourceGroupName |
  Format-Table -AutoSize

Write-Output "Report complete."
