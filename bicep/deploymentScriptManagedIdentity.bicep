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

resource readerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
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

// Assign the Reader role the Application Load Balancer user-assigned managed identity with the AKS cluster node resource group as a scope
module nodeResourceGroupReaderRoleAssignment 'resourceGroupRoleAssignment.bicep' = {
  name: guid(nodeResourceGroupName, managedIdentity.name, readerRole.id)
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    principalId: managedIdentity.properties.principalId
    roleName: readerRole.name
  }
}

// Outputs
output id string = managedIdentity.id
output name string = managedIdentity.name
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
