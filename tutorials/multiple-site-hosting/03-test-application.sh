#!/bin/bash

# Get the FQDN of the gateway
fqdn=$(kubectl get gateway gateway-02 -n test-infra -o jsonpath='{.status.addresses[0].value}')
echo "FQDN: $fqdn"

# Get the IP address of the gateway
fqdnIp=$(dig +short $fqdn)
echo "FQDN IP: $fqdnIp"

# Invoke contoso.com
curl -k --resolve contoso.com:80:$fqdnIp http://contoso.com; echo

# Invoke fabrikam.com
curl -k --resolve fabrikam.com:80:$fqdnIp http://fabrikam.com; echo

