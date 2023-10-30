#!/bin/bash

# Get the FQDN of the gateway
fqdn=$(kubectl get gateway gateway-01 -n test-infra -o jsonpath='{.status.addresses[0].value}')
echo "FQDN: $fqdn"

# Invoke the application
curl -k https://$fqdn; echo