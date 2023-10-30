#!/bin/bash

# For more information, see:
# https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/how-to-ssl-offloading-gateway-api?tabs=alb-managed

# Variables
source ./00-variables.sh

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
  yq "(.metadata.annotations."\""cert-manager.io/issuer"\"")|="\""$issuerName"\" |
  yq "(.metadata.annotations."\""alb.networking.azure.io/alb-name"\"")|="\""$applicationLoadBalancerName"\" |
  yq "(.metadata.annotations."\""alb.networking.azure.io/alb-namespace"\"")|="\""$applicationLoadBalancerNamespace"\" |
  yq "(.spec.listeners[1].hostname)|="\""$hostname"\" |
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