#!/bin/bash

# Get the FQDN of the gateway
fqdn=$(kubectl get gateway gateway-05 -n test-infra -o jsonpath='{.status.addresses[0].value}')
echo "FQDN: $fqdn"

# Get the IP address of the gateway
fqdnIp=$(dig +short $fqdn)
echo "FQDN IP: $fqdnIp"

# This curl command will return 50% of the responses from backend-v1 and the remaining 50% of the responses from backend-v2
watch -n 1 curl http://$fqdn

