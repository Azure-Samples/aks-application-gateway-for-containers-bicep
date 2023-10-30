#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api?tabs=alb-managed

# Variables
source ./00-variables.sh

# Retrieve the resource id of the Application Gateway for Containers
echo "Retrieving the resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers..."
id=$(az network alb show \
  --name $applicationGatewayForContainersName \
  --resource-group $resourceGroupName \
  --only-show-errors \
  --query id \
  --output tsv)

if [[ -n $id ]]; then
  echo "[$id] resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers successfully retrieved"
else
  echo "Failed to retrieve the resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers"
  exit
fi

# Check if the Application Gateway for Containers frontend already exists
echo "Checking if the [$frontendName] frontend actually exists in the [$applicationGatewayForContainersName] Application Gateway for Containers..."
az network alb frontend show \
  --name $frontendName \
  --resource-group $resourceGroupName \
  --alb-name $applicationGatewayForContainersName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$frontendName] frontend does not exist in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  echo "Creating [$frontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Create the Application Gateway for Containers frontend
  az network alb frontend create \
    --name $frontendName \
    --resource-group $resourceGroupName \
    --alb-name $applicationGatewayForContainersName \
    --only-show-errors  &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$frontendName] frontend successfully created in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  else
    echo "Failed to create [$frontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$frontendName] frontend already exists in the [$applicationGatewayForContainersName] Application Gateway for Containers"
fi

# Check if namespace exists in the cluster
result=$(kubectl get namespace -o jsonpath="{.items[?(@.metadata.name=='$namespace')].metadata.name}")

if [[ -n $result ]]; then
  echo "$namespace namespace already exists in the cluster"
else
  echo "$namespace namespace does not exist in the cluster"
  echo "creating $namespace namespace in the cluster..."
  kubectl create namespace $namespace
fi

# Create a sample web application
kubectl apply -n $namespace -f ./deployment.yaml

# Create Gateway
cat gateway.yaml |
  yq "(.metadata.name)|="\""$gatewayName"\" |
  yq "(.metadata.namespace)|="\""$namespace"\" |
  yq "(.metadata.annotations."\""alb.networking.azure.io/alb-id"\"")|="\""$id"\" |
  yq "(.metadata.annotations."\""cert-manager.io/issuer"\"")|="\""$issuerName"\" |
  yq "(.spec.listeners[1].hostname)|="\""$hostname"\" |
  yq "(.spec.addresses[0].value)|="\""$frontendName"\" |
kubectl apply -f -

# Create Issuer
cat issuer.yaml |
  yq "(.metadata.name)|="\""$issuerName"\" |
  yq "(.metadata.namespace)|="\""$namespace"\" |
  yq "(.spec.acme.solvers[0].http01.gatewayHTTPRoute.parentRefs[0].name)|="\""$gatewayName"\" |
  yq "(.spec.acme.solvers[0].http01.gatewayHTTPRoute.parentRefs[0].namespace)|="\""$namespace"\" |
kubectl apply -f -

# Create HTTPRoute
cat httproute.yaml |
  yq "(.metadata.name)|="\""$httpRouteName"\" |
  yq "(.metadata.namespace)|="\""$namespace"\" |
  yq "(.spec.parentRefs[0].name)|="\""$gatewayName"\" |
  yq "(.spec.parentRefs[0].namespace)|="\""$namespace"\" |
kubectl apply -f -