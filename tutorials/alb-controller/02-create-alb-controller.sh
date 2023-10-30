#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller?tabs=install-helm-linux

# Variables
source ./00-variables.sh

# Retrieve the clientId of the user-assigned managed identity
echo "Retrieving clientId for [$managedIdentityName] managed identity..."
clientId=$(az identity show \
  --name $managedIdentityName \
  --resource-group $aksResourceGroupName \
  --query clientId \
  --output tsv)

if [[ -n $clientId ]]; then
  echo "[$clientId] clientId  for the [$managedIdentityName] managed identity successfully retrieved"
else
  echo "Failed to retrieve clientId for the [$managedIdentityName] managed identity"
  exit
fi

helm upgrade alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --install \
  --version 0.4.023971 \
  --set albController.podIdentity.clientID=$clientId