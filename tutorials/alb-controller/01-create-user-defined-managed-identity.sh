#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller?tabs=install-helm-linux

# Variables
source ./00-variables.sh

# Retrieve the name of the node resource group of the AKS cluster
echo "Retrieving the name of the node resource group of the [$aksName] AKS cluster..."
mcResourceGroupName=$(az aks show \
  --name $aksName \
  --resource-group $aksResourceGroupName  \
  --query "nodeResourceGroup" \
  --output tsv \
  --only-show-errors)

if [[ -n $mcResourceGroupName ]]; then
  echo "[$mcResourceGroupName] node resource group of the [$aksName] AKS cluster successfully retrieved"
else
  echo "Failed to retrieve the name of the node resource group of the [$aksName] AKS cluster"
  exit
fi

# Retrieve the resource id of the node resource group of the AKS cluster
echo "Retrieving the resource id of the [$mcResourceGroupName] resource group..."
mcResourceGroupId=$(az group show --name $mcResourceGroupName --query id -otsv)

if [[ -n $mcResourceGroupId ]]; then
  echo "[$mcResourceGroupId] resource id of the [$mcResourceGroupName] resource group successfully retrieved"
else
  echo "Failed to retrieve the resource id of the [$mcResourceGroupName] resource group"
  exit
fi

# Check if the user-assigned managed identity already exists
echo "Checking if [$managedIdentityName] user-assigned managed identity actually exists in the [$aksResourceGroupName] resource group..."

az identity show \
  --name $managedIdentityName \
  --resource-group $aksResourceGroupName &>/dev/null

if [[ $? != 0 ]]; then
  echo "No [$managedIdentityName] user-assigned managed identity actually exists in the [$aksResourceGroupName] resource group"
  echo "Creating [$managedIdentityName] user-assigned managed identity in the [$aksResourceGroupName] resource group..."

  # Create the user-assigned managed identity
  az identity create \
    --name $managedIdentityName \
    --resource-group $aksResourceGroupName \
    --location $location \
    --subscription $subscriptionId 1>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$managedIdentityName] user-assigned managed identity successfully created in the [$aksResourceGroupName] resource group"
    echo "Waiting 60 seconds to allow for replication of the identity..."
    sleep 60
  else
    echo "Failed to create [$managedIdentityName] user-assigned managed identity in the [$aksResourceGroupName] resource group"
    exit
  fi
else
  echo "[$managedIdentityName] user-assigned managed identity already exists in the [$aksResourceGroupName] resource group"
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

# Assign the Reader role on the node resource group to the the managed identity
role="Reader"
echo "Checking if the [$managedIdentityName] managed identity has been assigned to [$role] role with the [$mcResourceGroupName] node resource group as a scope..."
current=$(az role assignment list \
  --assignee $principalId \
  --scope $mcResourceGroupId \
  --query "[?roleDefinitionName=='$role'].roleDefinitionName" \
  --output tsv)

if [[ "$current == $role" ]]; then
  echo "[$managedIdentityName] managed identity is already assigned to the ["$current"] role with the [$mcResourceGroupName] node resource group as a scope"
else
  echo "[$managedIdentityName] managed identity is not assigned to the [$role] role with the [$mcResourceGroupName] node resource group as a scope"
  echo "Assigning the [$role] role to the [$managedIdentityName] managed identity with the [$mcResourceGroupName] node resource group as a scope..."

  az role assignment create \
    --assignee-object-id $principalId \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope $mcResourceGroupId &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$managedIdentityName] managed identity successfully assigned to the [$role] role with the [$mcResourceGroupName] node resource group as a scope"
  else
    echo "Failed to assign the [$managedIdentityName] managed identity to the [$role] role with the [$mcResourceGroupName] node resource group as a scope"
    exit
  fi
fi

# Check if the federated identity credential already exists
echo "Checking if [$federatedIdentityName] federated identity credential actually exists in the [$aksResourceGroupName] resource group..."

az identity federated-credential show \
  --name $federatedIdentityName \
  --resource-group $aksResourceGroupName \
  --identity-name $managedIdentityName &>/dev/null

if [[ $? != 0 ]]; then
  echo "No [$federatedIdentityName] federated identity credential actually exists in the [$aksResourceGroupName] resource group"

  # Get the OIDC Issuer URL
  aksOidcIssuerUrl="$(az aks show \
    --only-show-errors \
    --name $aksName \
    --resource-group $aksResourceGroupName \
    --query oidcIssuerProfile.issuerUrl \
    --output tsv)"

  # Show OIDC Issuer URL
  if [[ -n $aksOidcIssuerUrl ]]; then
    echo "The OIDC Issuer URL of the $aksName cluster is $aksOidcIssuerUrl"
  fi

  echo "Creating [$federatedIdentityName] federated identity credential in the [$aksResourceGroupName] resource group..."

  # Establish the federated identity credential between the managed identity, the service account issuer, and the subject.
  az identity federated-credential create \
    --name $federatedIdentityName \
    --identity-name $managedIdentityName \
    --resource-group $aksResourceGroupName \
    --issuer $aksOidcIssuerUrl \
    --subject system:serviceaccount:$namespace:$serviceAccountName &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$federatedIdentityName] federated identity credential successfully created in the [$aksResourceGroupName] resource group"
  else
    echo "Failed to create [$federatedIdentityName] federated identity credential in the [$aksResourceGroupName] resource group"
    exit
  fi
else
  echo "[$federatedIdentityName] federated identity credential already exists in the [$aksResourceGroupName] resource group"
fi