#!/bin/bash

# Get the FQDN of the gateway
fqdn=$(kubectl get gateway gateway-04 -n test-infra -o jsonpath='{.status.addresses[0].value}')
echo "FQDN: $fqdn"

# Get the IP address of the gateway
fqdnIp=$(dig +short $fqdn)
echo "FQDN IP: $fqdnIp"

# Curling this FQDN should return responses from the backend as configured on the HTTPRoute
curl --insecure https://$fqdn/;echo

