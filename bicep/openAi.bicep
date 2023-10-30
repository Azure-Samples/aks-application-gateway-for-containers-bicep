// Parameters
@description('Specifies the name of the Azure OpenAI resource.')
param name string = 'aks-${uniqueString(resourceGroup().id)}'

@description('Specifies the resource model definition representing SKU.')
param sku object = {
  name: 'S0'
}

@description('Specifies the identity of the OpenAI resource.')
param identity object = {
  type: 'SystemAssigned'
}

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the resource tags.')
param tags object

@description('Specifies an optional subdomain name used for token-based authentication.')
param customSubDomainName string = ''

@description('Specifies whether or not public endpoint access is allowed for this account..')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Specifies the OpenAI deployments to create.')
param deployments array = [
  {
    name: 'gpt-35-turbo-16k'
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo-16k'
      version: '0613'
    }
    sku: {
      name: 'Standard'
      capacity: 30
    }
  }
   {
    name: 'text-embedding-ada-002'
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
    sku: {
      name: 'Standard'
      capacity: 30
    }
  }
]

@description('Specifies the workspace id of the Log Analytics used to monitor the Application Gateway.')
param workspaceId string

// Variables
var diagnosticSettingsName = 'diagnosticSettings'
var openAiLogCategories = [
  'Audit'
  'RequestResponse'
  'Trace'
]
var openAiMetricCategories = [
  'AllMetrics'
]
var openAiLogs = [for category in openAiLogCategories: {
  category: category
  enabled: true
}]
var openAiMetrics = [for category in openAiMetricCategories: {
  category: category
  enabled: true
}]

// Resources
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  sku: sku
  kind: 'OpenAI'
  identity: identity
  tags: tags
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
  }
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  name: deployment.name
  parent: openAi
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

resource openAiDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingsName
  scope: openAi
  properties: {
    workspaceId: workspaceId
    logs: openAiLogs
    metrics: openAiMetrics
  }
}

// Outputs
output id string = openAi.id
output name string = openAi.name
