param environment string
param appServicePlanName string
param appInsightsName string
param storageAccountName string
param keyVaultName string
param appServiceName string
param appServicePlanSku string
param appServiceTier string
param appServicePlansize string
param keyVaultFamily string
param keyVaultKind string
param accessPolicies array
param storageAccountSku string
param storageAccountKind string

var truncatedStorageAccountName = take(storageAccountName, 5)
var randomizedStorageAccountName = '${environment}${truncatedStorageAccountName}${uniqueString(resourceGroup().id, truncatedStorageAccountName)}'
var truncatedKeyVaultName = take(keyVaultName, 5)
var randomizedKeyVaultName = '${environment}${truncatedKeyVaultName}${uniqueString(resourceGroup().id, truncatedKeyVaultName)}'

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: randomizedKeyVaultName
  location: resourceGroup().location
  properties: {
    sku: {
      family: keyVaultFamily //family: 'A'
      name: keyVaultKind //standard
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId:  accessPolicies[0].objectId
        permissions: {
          keys: ['all']
          secrets: ['all']
          certificates: ['all']
        }
      }
      {
        tenantId: subscription().tenantId
        objectId:  accessPolicies[1].objectId
        permissions: {
          keys: ['all']
          secrets: ['all']
          certificates: ['all']
        }
      }      
    ]
  }
  tags: { environment: environment }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: randomizedStorageAccountName
  location: resourceGroup().location
  sku: {
    name: storageAccountSku //Standard_LRS
  }
  kind: storageAccountKind //StorageV2
  tags: { environment: environment }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${randomizedStorageAccountName}/default/webcontent'
  properties: {
    publicAccess: 'Blob'
  }
}

resource storageAccountKeys 'Microsoft.Storage/storageAccounts/listKeys@2021-04-01' = {
  name: 'listKeys'
  parent: storageAccount
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  name: 'storageAccountKey'
  parent: keyVault
  properties: {
    value: listKeys(storageAccount.id, '2019-04-01').keys[0].value
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: resourceGroup().location
  sku: {
    name: appServicePlanSku //F1
    tier: appServiceTier //Free
    size: appServicePlansize
  }
  tags: { environment: environment }
}

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: resourceGroup().location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      azureStorageAccounts: {
        myStorage: {
          type: 'AzureBlob'
          accountName: storageAccount.name
            accessKey: keyVaultSecret.properties.value
          shareName: blobContainer.name
          mountPath: '/webcontent'
        }
      }
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: resourceGroup().location
  kind: 'web'
  tags: { environment: environment }
}

output storageAccountName string = storageAccount.name
output storageAccountConnection string = storageAccount.properties.primaryEndpoints.blob
output keyVaultName string = keyVault.name
output appServicePlan string = appServicePlan.name
output appServiceName string = appService.name
output appInsightsName string = appInsights.name
