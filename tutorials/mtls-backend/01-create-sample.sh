#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-backend-mtls-gateway-api?tabs=alb-managed

# Variables
source ../alb-controller/00-variables.sh

# Create a sample web application and deploy sample secrets to demonstrate backend mutual authentication (mTLS).
kubectl apply -f https://trafficcontrollerdocs.blob.core.windows.net/examples/https-scenario/end-to-end-ssl-with-backend-mtls/deployment.yaml

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

# Create Gateway
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: gateway-01
  namespace: test-infra
  annotations:
    alb.networking.azure.io/alb-id: $id
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: https-listener
    port: 443
    protocol: HTTPS
    allowedRoutes:
      namespaces:
        from: Same
    tls:
      mode: Terminate
      certificateRefs:
      - kind : Secret
        group: ""
        name: frontend.com
  addresses:
  - type: alb.networking.azure.io/alb-frontend
    value: $frontendName
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show Gateway YAML manifest
kubectl get gateway gateway-01 -n test-infra -o yaml