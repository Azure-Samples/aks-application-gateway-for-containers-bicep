#!/bin/bash

# Get the FQDN of the ingress
fqdn=$(kubectl get ingress ingress-01 -n test-infra -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "FQDN: $fqdn"

# Get the IP address of the gateway
fqdnIp=$(dig +short $fqdn)
echo "FQDN IP: $fqdnIp"

# Curling this FQDN should return responses from the backend as configured in the ingress
curl -vik --resolve example.com:443:$fqdnIp https://example.com;echo