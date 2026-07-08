#!/usr/bin/env bash
# Azure Administration bootstrap for Azure Cloud Shell — creates ~/azadmin.
mkdir -p ~/azadmin/bicep && cd ~/azadmin

cat > bicep/main.bicep <<'EOF'
@description('Region.')
param location string = resourceGroup().location
@description('Naming prefix.')
param namePrefix string = 'azadmin'

var suffix = substring(uniqueString(resourceGroup().id), 0, 5)

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}${suffix}sa')
  location: location
  tags: {
    environment: 'dev'
    owner: 'platform-team'
  }
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
EOF

cat > lifecycle.json <<'EOF'
{
  "rules": [
    {
      "enabled": true,
      "name": "cool-then-delete",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 30 },
            "delete": { "daysAfterModificationGreaterThan": 365 }
          }
        },
        "filters": { "blobTypes": [ "blockBlob" ] }
      }
    }
  ]
}
EOF

echo "=== Azure Administration files created in ~/azadmin ==="
find . -type f | sort
