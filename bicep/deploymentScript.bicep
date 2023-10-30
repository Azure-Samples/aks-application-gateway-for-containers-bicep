// For more information, see https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-script-bicep
@description('Specifies the name of the deployment script uri.')
param name string = 'DeploymentScript' 

@description('Specifies the name of the storage account used by the deployment script.')
param storageAccountName string = 'serverboot${uniqueString(resourceGroup().id)}'

@description('Specifies the resource id of the user-defined managed identity used by the deployment script.')
param managedIdentityId string 

@description('Specifies the primary script URI.')
param primaryScriptUri string

@description('Specifies the name of the AKS cluster.')
param clusterName string

@description('Specifies the resource group name')
param resourceGroupName string = resourceGroup().name

@description('Specifies the name of the AKS node resource group')
param nodeResourceGroupName string = resourceGroup().name

@description('Specifies the Azure AD tenant id.')
param tenantId string = subscription().tenantId

@description('Specifies the subscription id.')
param subscriptionId string = subscription().subscriptionId

@description('Specifies whether creating the Application Gateway and enabling the Application Gateway Ingress Controller or not.')
param applicationGatewayEnabled string

@description('Specifies the service account of the application.')
param serviceAccountName string = ''

@description('Specifies the client id of the workload user-defined managed identity.')
param workloadManagedIdentityClientId string

@description('Specifies whether the Application Gateway for Containers is managed or bring your own (BYO).')
@allowed([
  'managed'
  'byo'
])
param applicationGatewayForContainersType string

@description('Specifies whether creating an Application Gateway for Containers or not.')
param applicationGatewayForContainersEnabled string

@description('Specifies the namespace of the Application Load Balancer controller.')
param applicationGatewayForContainersNamespace string = 'azure-alb-system'

@description('Specifies the client id of the user-defined managed identity of the Application Gateway for Containers.')
param applicationGatewayForContainersManagedIdentityClientId string = ''

@description('Specifies the resource id of the subnet which contains the Application Gateway for Containers.')
param applicationGatewayForContainersSubnetId string = ''

@description('Specifies the workspace id of the Log Analytics used to monitor the Application Gateway for Containers.')
param workspaceId string

@description('Specifies the hostname of the application.')
param hostName string

@description('Specifies the namespace of the application.')
param namespace string

@description('Specifies the email address for the cert-manager cluster issuer.')
param email string

@description('Specifies the current datetime')
param utcValue string = utcNow()

@description('Specifies the location.')
param location string

@description('Specifies the resource tags.')
param tags object

// Resources
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

// Script
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: name
  location: location
  kind: 'AzureCLI'
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.52.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'clusterName'
        value: clusterName
      }
      {
        name: 'resourceGroupName'
        value: resourceGroupName
      }
      {
        name: 'nodeResourceGroupName'
        value: nodeResourceGroupName
      }
      {
        name: 'applicationGatewayEnabled'
        value: applicationGatewayEnabled
      }
      {
        name: 'tenantId'
        value: tenantId
      }
      {
        name: 'subscriptionId'
        value: subscriptionId
      }
      {
        name: 'hostName'
        value: hostName
      }
      {
        name: 'namespace'
        value: namespace
      }
      {
        name: 'serviceAccountName'
        value: serviceAccountName
      }
      {
        name: 'workloadManagedIdentityClientId'
        value: workloadManagedIdentityClientId
      }
      {
        name: 'applicationGatewayForContainersType'
        value: applicationGatewayForContainersType
      }
      {
        name: 'applicationGatewayForContainersEnabled'
        value: applicationGatewayForContainersEnabled
      }
      {
        name: 'applicationGatewayForContainersNamespace'
        value: applicationGatewayForContainersNamespace}
      {
        name: 'applicationGatewayForContainersManagedIdentityClientId'
        value: applicationGatewayForContainersManagedIdentityClientId
      }
      {
        name: 'applicationGatewayForContainersSubnetId'
        value: applicationGatewayForContainersSubnetId
      }
      {
        name: 'workspaceId'
        value: workspaceId
      }
      {
        name: 'email'
        value: email
      }
    ]
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
    primaryScriptUri: primaryScriptUri
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// Outputs
output result object = deploymentScript.properties.outputs
output certManager string = deploymentScript.properties.outputs.certManager
output applicationGatewayForContainersName string = deploymentScript.properties.outputs.applicationGatewayForContainersName
