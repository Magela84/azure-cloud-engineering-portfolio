#!/usr/bin/env bash
# FinOps bootstrap for Azure Cloud Shell — creates ~/azfin.
mkdir -p ~/azfin/bicep && cd ~/azfin

cat > bicep/budget.bicep <<'EOF'
targetScope = 'subscription'
@description('Budget name.')
param budgetName string = 'monthly-cost-budget'
@description('Monthly limit.')
param amount int = 50
@description('Alert email — replace at deploy time.')
param alertEmail string = 'you@example.com'
@description('First day of current month YYYY-MM-01.')
param startDate string = '2026-07-01'
@description('End date within 10 years.')
param endDate string = '2027-07-01'

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: {
      alertAt80Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        contactEmails: [ alertEmail ]
        thresholdType: 'Actual'
      }
      forecastOver100Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        contactEmails: [ alertEmail ]
        thresholdType: 'Forecasted'
      }
    }
  }
}

output budgetId string = budget.id
EOF

cat > bicep/tagged-resource.bicep <<'EOF'
param location string = resourceGroup().location
param namePrefix string = 'azfin'
var suffix = substring(uniqueString(resourceGroup().id), 0, 5)
var costTags = {
  costCenter: 'engineering-123'
  environment: 'dev'
  owner: 'platform-team'
  project: 'finops-demo'
}
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}${suffix}sa')
  location: location
  tags: costTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}
output storageAccountName string = storage.name
output appliedTags object = costTags
EOF

echo "=== FinOps files created in ~/azfin ==="
find . -type f | sort
