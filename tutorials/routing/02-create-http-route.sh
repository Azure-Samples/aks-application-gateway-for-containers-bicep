#!/bin/bash

# Create an HTTPRoute to define two different matches and a default service to route traffic to.
# The way the following rules read are as follows:
# - If the path is /bar, traffic is routed to backend-v2 service on port 8080 OR
# - If the request contains an HTTP header with the name magic and the value foo, the URL contains a query string defining a parameter with the name great and value example, AND the path is /some/thing, the request is sent to backend-v2 on port 8080.
# - Otherwise, all other requests are routed to backend-v1 service on port 8080.
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: http-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-03
    namespace: test-infra
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /bar
    backendRefs:
    - name: backend-v2
      port: 8080
  - matches:
    - headers:
      - type: Exact
        name: magic
        value: foo
      queryParams:
      - type: Exact
        name: great
        value: example
      path:
        type: PathPrefix
        value: /some/thing
      method: GET
    backendRefs:
    - name: backend-v2
      port: 8080
  - backendRefs:
    - name: backend-v1
      port: 8080
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show HTTPRoute YAML manifest
kubectl get httproute http-route -n test-infra -o yaml