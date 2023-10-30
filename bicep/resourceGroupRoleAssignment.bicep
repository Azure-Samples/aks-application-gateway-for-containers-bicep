// Parameters
@description('Specifies the name of role.')
param roleName string

@description('Specifies the principal id of the managed identity or service principal.')
param principalId string

// Resources
resource role 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roleName
  scope: subscription()
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().name, roleName, principalId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: role.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
