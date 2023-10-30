#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment?tabs=existing-vnet-subnet

# Variables
source ./00-variables.sh

# Check if the Application Gateway for Containers resource already exists
echo "Checking if [$applicationGatewayForContainersName] Application Gateway for Containers resource actually exists in the [$aksResourceGroupName] resource group..."
az network alb show \
  --name $applicationGatewayForContainersName \
  --resource-group $aksResourceGroupName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$applicationGatewayForContainersName] Application Gateway for Containers does not exist in the [$aksResourceGroupName] resource group"
  echo "Creating [$applicationGatewayForContainersName] Application Gateway for Containers in the [$aksResourceGroupName] resource group..."

  # Create the Application Gateway for Containers resource
  az network alb create \
    --name $applicationGatewayForContainersName \
    --resource-group $aksResourceGroupName \
    --location $location \
    --only-show-errors  1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$applicationGatewayForContainersName] Application Gateway for Containers successfully created in the [$aksResourceGroupName] resource group"
  else
    echo "Failed to create [$applicationGatewayForContainersName] Application Gateway for Containers in the [$aksResourceGroupName] resource group"
    exit
  fi
else
  echo "[$applicationGatewayForContainersName] Application Gateway for Containers already exists in the [$aksResourceGroupName] resource group"
fi

# Check if the Application Gateway for Containers frontend already exists
echo "Checking if the [$frontendName] frontend actually exists in the [$applicationGatewayForContainersName] Application Gateway for Containers..."
az network alb frontend show \
  --name $frontendName \
  --resource-group $aksResourceGroupName \
  --alb-name $applicationGatewayForContainersName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$frontendName] frontend does not exist in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  echo "Creating [$frontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Create the Application Gateway for Containers frontend
  az network alb frontend create \
    --name $frontendName \
    --resource-group $aksResourceGroupName \
    --alb-name $applicationGatewayForContainersName \
    --only-show-errors  1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$frontendName] frontend successfully created in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  else
    echo "Failed to create [$frontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$frontendName] frontend already exists in the [$applicationGatewayForContainersName] Application Gateway for Containers"
fi

# Check if the subnet already exists
echo "Checking if [$subnetName] subnet actually exists in the [$virtualNetworkName] virtual network..."
az network vnet subnet show \
  --name $subnetName \
  --resource-group $aksResourceGroupName \
  --vnet-name $virtualNetworkName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$subnetName] subnet does not exist in the [$virtualNetworkName] virtual network"
  echo "Creating [$subnetName] subnet in the [$virtualNetworkName] virtual network..."

  # Create the subnet
  az network vnet subnet create \
    --name $subnetName \
    --resource-group $aksResourceGroupName \
    --vnet-name $virtualNetworkName \
    --address-prefixes $subnetAddressPrefix \
    --only-show-errors  1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$subnetName] subnet successfully created in the [$virtualNetworkName] virtual network"
  else
    echo "Failed to create [$subnetName] subnet in the [$virtualNetworkName] virtual network"
    exit
  fi
else
  echo "[$subnetName] subnet already exists in the [$virtualNetworkName] virtual network"
fi

# Check if the subnet is already delegated to the Application Gateway for Containers
echo "Checking if the [$subnetName] subnet of the [$virtualNetworkName] virtual network is already delegated to the [$applicationGatewayForContainersName] Application Gateway for Containers..."
delegationName=$(az network vnet subnet show \
  --name $subnetName \
  --resource-group $aksResourceGroupName \
  --vnet-name $virtualNetworkName \
  --query "delegations[?serviceName=='Microsoft.ServiceNetworking/trafficControllers']|[0].name" \
  --output tsv \
  --only-show-errors)

if [[ -z $delegationName ]]; then
  echo "[$subnetName] subnet of the [$virtualNetworkName] virtual network is not delegated to the [$applicationGatewayForContainersName] Application Gateway for Containers"
  echo "Delegating the [$subnetName] subnet of the [$virtualNetworkName] virtual network to the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Delegate the subnet to the Application Gateway for Containers
  az network vnet subnet update \
    --resource-group $aksResourceGroupName  \
    --name $subnetName \
    --vnet-name $virtualNetworkName \
    --delegations 'Microsoft.ServiceNetworking/trafficControllers' \
    --only-show-errors  1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$subnetName] subnet of the [$virtualNetworkName] virtual network successfully delegated to the [$applicationGatewayForContainersName] Application Gateway for Containers"
  else
    echo "Failed to delegate the [$subnetName] subnet of the [$virtualNetworkName] virtual network to the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$subnetName] subnet of the [$virtualNetworkName] virtual network is already delegated to the [$applicationGatewayForContainersName] Application Gateway for Containers"
fi

# Retrieve the resource id of the resource group containing the Application Gateway for Containers resource
echo "Retrieving the resource id of the [$aksResourceGroupName] resource group..."
resourceGroupId=$(az group show \
  --name $aksResourceGroupName \
  --query id \
  --output tsv)

if [[ -n $resourceGroupId ]]; then
  echo "[$resourceGroupId] resource id of the [$aksResourceGroupName] resource group successfully retrieved"
else
  echo "Failed to retrieve the resource id of the [$aksResourceGroupName] resource group"
  exit
fi

# Retrieve the principalId of the user-assigned managed identity
echo "Retrieving principalId for [$managedIdentityName] managed identity..."
principalId=$(az identity show \
  --name $managedIdentityName \
  --resource-group $aksResourceGroupName \
  --query principalId \
  --output tsv)

if [[ -n $principalId ]]; then
  echo "[$principalId] principalId  for the [$managedIdentityName] managed identity successfully retrieved"
else
  echo "Failed to retrieve principalId for the [$managedIdentityName] managed identity"
  exit
fi

# Retrieve the resource if of the delegated subnet
echo "Retrieving the resource id of the [$subnetName] subnet of the [$virtualNetworkName] virtual network..."
subnetId=$(az network vnet subnet show \
  --name $subnetName \
  --resource-group $aksResourceGroupName \
  --vnet-name $virtualNetworkName \
  --query id \
  --output tsv \
  --only-show-errors)

if [[ -n $subnetId ]]; then
  echo "[$subnetId] resource id of the [$subnetName] subnet of the [$virtualNetworkName] virtual network successfully retrieved"
else
  echo "Failed to retrieve the resource id of the [$subnetName] subnet of the [$virtualNetworkName] virtual network"
  exit
fi

# Assign the AppGw for Containers Configuration Manager role on the resource group to the managed identity
role="AppGw for Containers Configuration Manager"
echo "Checking if the [$managedIdentityName] managed identity has been assigned to [$role] role with the [$aksResourceGroupName] resource group as a scope..."
current=$(az role assignment list \
  --assignee $principalId \
  --scope $resourceGroupId \
  --query "[?roleDefinitionName=='$role'].roleDefinitionName" \
  --output tsv)

if [[ "$current" == "$role" ]]; then
  echo "[$managedIdentityName] managed identity is already assigned to the ["$current"] role with the [$aksResourceGroupName] resource group as a scope"
else
  echo "[$managedIdentityName] managed identity is not assigned to the [$role] role with the [$aksResourceGroupName] resource group as a scope"
  echo "Assigning the [$role] role to the [$managedIdentityName] managed identity with the [$aksResourceGroupName] resource group as a scope..."

  az role assignment create \
    --assignee-object-id $principalId \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope $resourceGroupId 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$managedIdentityName] managed identity successfully assigned to the [$role] role with the [$aksResourceGroupName] resource group as a scope"
  else
    echo "Failed to assign the [$managedIdentityName] managed identity to the [$role] role with the [$aksResourceGroupName] resource group as a scope"
    exit
  fi
fi

# Assign the Network Contributor role on the resource group to the managed identity
role="Network Contributor"
echo "Checking if the [$managedIdentityName] managed identity has been assigned to [$role] role with the [$subnetName] subnet as a scope..."
current=$(az role assignment list \
  --assignee $principalId \
  --scope $subnetId \
  --query "[?roleDefinitionName=='$role'].roleDefinitionName" \
  --output tsv)

if [[ "$current" == "$role" ]]; then
  echo "[$managedIdentityName] managed identity is already assigned to the ["$current"] role with the [$subnetName] subnet as a scope"
else
  echo "[$managedIdentityName] managed identity is not assigned to the [$role] role with the [$subnetName] subnet as a scope"
  echo "Assigning the [$role] role to the [$managedIdentityName] managed identity with the [$subnetName] subnet as a scope..."

  az role assignment create \
    --assignee-object-id $principalId \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope $subnetId 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$managedIdentityName] managed identity successfully assigned to the [$role] role with the [$subnetName] subnet as a scope"
  else
    echo "Failed to assign the [$managedIdentityName] managed identity to the [$role] role with the [$subnetName] subnet as a scope"
    exit
  fi
fi

# Check if an association already exists for the Application Gateway for Containers frontend and the subnet
echo "Checking if an association already exists between the [$applicationGatewayForContainersName] Application Gateway for Containers and the [$subnetName] subnet..."
association=$(az network alb association show \
  --name $associationName \
  --resource-group $aksResourceGroupName \
  --alb-name $applicationGatewayForContainersName \
  --query name \
  --output tsv \
  --only-show-errors 2>/dev/null)

if [[ -z $association ]]; then
  echo "No association actually exists between the [$applicationGatewayForContainersName] Application Gateway for Containers and the [$subnetName] subnet"
  echo "Associating the [$applicationGatewayForContainersName] Application Gateway for Containers with the [$subnetName] subnet..."

  # Associate the Application Gateway for Containers frontend with the subnet
  az network alb association create \
    --name $associationName \
    --resource-group $aksResourceGroupName \
    --alb-name $applicationGatewayForContainersName \
    --subnet $subnetName \
    --vnet-name $virtualNetworkName \
    --only-show-errors 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$applicationGatewayForContainersName] Application Gateway for Containers successfully associated with the [$subnetName] subnet"
  else
    echo "Failed to associate the [$applicationGatewayForContainersName] Application Gateway for Containers with the [$subnetName] subnet"
    exit
  fi
else
  echo "An association already exists between the [$applicationGatewayForContainersName] Application Gateway for Containers and the [$subnetName] subnet"
fi

# Retrieve the resource id of the Application Gateway for Containers
echo "Retrieving the resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers..."
applicationGatewayForContainersId=$(az network alb show \
  --name $applicationGatewayForContainersName \
  --resource-group $aksResourceGroupName \
  --query id \
  --output tsv \
  --only-show-errors)

if [[ -n $applicationGatewayForContainersId ]]; then
  echo "[$applicationGatewayForContainersId] resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers successfully retrieved"
else
  echo "Failed to retrieve the resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers"
  exit
fi

# Check if the diagnostic setting already exists for the Application Gateway for Containers
echo "Checking if the [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers actually exists..."
name=$(az monitor diagnostic-settings show \
  --name $diagnosticSettingName \
  --resource $applicationGatewayForContainersId \
  --query name \
  --output tsv 2>/dev/null)

if [[ -z $name ]]; then
  echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers does not exist"
  echo "Creating [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Create the diagnostic setting for the Application Gateway for Containers
  az monitor diagnostic-settings create \
    --name $diagnosticSettingName \
    --resource $applicationGatewayForContainersId \
    --logs '[{"categoryGroup": "allLogs", "enabled": true}]' \
    --metrics '[{"category": "AllMetrics", "enabled": true}]' \
    --workspace $logAnalyticsWorkspaceName \
    --only-show-errors 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers successfully created"
  else
    echo "Failed to create [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers already exists"
fi

