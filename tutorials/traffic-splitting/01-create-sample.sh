#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api?tabs=alb-managed

# Variables
source ../alb-controller/00-variables.sh

# Create a sample web application to demonstrate path, query, and header based routing.
# kubectl apply -f https://trafficcontrollerdocs.blob.core.windows.net/examples/traffic-split-scenario/deployment.yaml
kubectl apply -f ./deployment.yaml

# Retrieve the resource id of the Application Gateway for Containers
echo "Retrieving the resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers..."
id=$(az network alb show \
  --name $applicationGatewayForContainersName \
  --resource-group $aksResourceGroupName \
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
echo "Checking if the [$trafficSplittingFrontendName] frontend actually exists in the [$applicationGatewayForContainersName] Application Gateway for Containers..."
az network alb frontend show \
  --name $trafficSplittingFrontendName \
  --resource-group $aksResourceGroupName \
  --alb-name $applicationGatewayForContainersName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$trafficSplittingFrontendName] frontend does not exist in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  echo "Creating [$trafficSplittingFrontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Create the Application Gateway for Containers frontend
  az network alb frontend create \
    --name $trafficSplittingFrontendName \
    --resource-group $aksResourceGroupName \
    --alb-name $applicationGatewayForContainersName \
    --only-show-errors  &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$trafficSplittingFrontendName] frontend successfully created in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  else
    echo "Failed to create [$trafficSplittingFrontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$trafficSplittingFrontendName] frontend already exists in the [$applicationGatewayForContainersName] Application Gateway for Containers"
fi

# Create Gateway
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: gateway-05
  namespace: test-infra
  annotations:
    alb.networking.azure.io/alb-id: $id
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  addresses:
  - type: alb.networking.azure.io/alb-frontend
    value: $trafficSplittingFrontendName
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show Gateway YAML manifest
kubectl get gateway gateway-05 -n test-infra -o yaml
