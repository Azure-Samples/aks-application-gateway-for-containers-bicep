#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api?tabs=alb-managed

# Variables
source ../alb-controller/00-variables.sh

# Create a sample web application to demonstrate path, query, and header based routing.
# kubectl apply -f https://trafficcontrollerdocs.blob.core.windows.net/examples/https-scenario/ssl-termination/deployment.yaml
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
echo "Checking if the [$sslOffloadingFrontendName] frontend actually exists in the [$applicationGatewayForContainersName] Application Gateway for Containers..."
az network alb frontend show \
  --name $sslOffloadingFrontendName \
  --resource-group $aksResourceGroupName \
  --alb-name $applicationGatewayForContainersName \
  --only-show-errors &>/dev/null

if [[ $? != 0 ]]; then
  echo "[$sslOffloadingFrontendName] frontend does not exist in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  echo "Creating [$sslOffloadingFrontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers..."

  # Create the Application Gateway for Containers frontend
  az network alb frontend create \
    --name $sslOffloadingFrontendName \
    --resource-group $aksResourceGroupName \
    --alb-name $applicationGatewayForContainersName \
    --only-show-errors  &>/dev/null

  if [[ $? == 0 ]]; then
    echo "[$sslOffloadingFrontendName] frontend successfully created in the [$applicationGatewayForContainersName] Application Gateway for Containers"
  else
    echo "Failed to create [$sslOffloadingFrontendName] frontend in the [$applicationGatewayForContainersName] Application Gateway for Containers"
    exit
  fi
else
  echo "[$sslOffloadingFrontendName] frontend already exists in the [$applicationGatewayForContainersName] Application Gateway for Containers"
fi

# Create Gateway
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-01
  namespace: test-infra
  annotations:
    alb.networking.azure.io/alb-id: $id
    alb.networking.azure.io/alb-frontend: $sslOffloadingFrontendName
spec:
  ingressClassName: azure-alb-external
  tls:
  - hosts:
    - example.com
    secretName: listener-tls-secret
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: echo
            port:
              number: 80
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show Gateway YAML manifest
kubectl get ingress ingress-01 -n test-infra -o yaml
