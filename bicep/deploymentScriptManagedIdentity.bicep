// Parameters
@description('Specifies the name of the user-defined managed identity used by the deployment script.')
param name string = 'ScriptManagedIdentity' 

@description('Specifies the name of the AKS cluster.')
param clusterName string

@description('Specifies the name of the AKS cluster node resource group. This needs to be passed as a parameter and cannot be calculated inside this module.')
param nodeResourceGroupName string

@description('Specifies the location.')
param location string

@description('Specifies the resource tags.')
param tags object

// Resources
resource clusterAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
  scope: subscription()
}

resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-11-02-preview' existing = {
  name: clusterName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

// Assign the Cluster Admin role to the user-assigned managed identity with the AKS cluster as a scope
resource clusterAdminContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid(managedIdentity.id, aksCluster.id, clusterAdminRole.id)
  scope: aksCluster
  properties: {
    roleDefinitionId: clusterAdminRole.id
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Assign the Contributor role to the user-assigned managed identity with the AKS cluster node resource group as a scope
module nodeResourceGroupContributorRoleAssignment 'resourceGroupRoleAssignment.bicep' = {
  name: guid(nodeResourceGroupName, managedIdentity.name, contributorRole.id)
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    principalId: managedIdentity.properties.principalId
    roleName: contributorRole.name
  }
}

// Assign the Contributor role the user-assigned managed identity with the AKS cluster resource group as a scope
module resourceGroupContributorRoleAssignment 'resourceGroupRoleAssignment.bicep' = {
  name: guid(resourceGroup().name, managedIdentity.name, contributorRole.id)
  scope: resourceGroup()
  params: {
    principalId: managedIdentity.properties.principalId
    roleName: contributorRole.name
  }
}

// Outputs
output id string = managedIdentity.id
output name string = managedIdentity.name
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
