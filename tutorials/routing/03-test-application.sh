#!/bin/bash

# Get the FQDN of the gateway
fqdn=$(kubectl get gateway gateway-03 -n test-infra -o jsonpath='{.status.addresses[0].value}')
echo "FQDN: $fqdn"

# Get the IP address of the gateway
fqdnIp=$(dig +short $fqdn)
echo "FQDN IP: $fqdnIp"

# In this scenario, the client request sent to http://frontend-fqdn/bar is routed to backend-v2 service.
curl http://$fqdn/bar; echo

# In this scenario, the client request sent to http://frontend-fqdn/some/thing?great=example with a header key/value part of "magic: foo" is routed to backend-v2 service.
curl http://$fqdn/some/thing?great=example -H "magic: foo"; echo

# If neither of the first two scenarios are satisfied, Application Gateway for Containers routes all other requests to the backend-v1 service.
curl http://$fqdn; echo

