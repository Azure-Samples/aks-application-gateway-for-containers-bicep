#!/bin/bash

# Create an HTTPRoute
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: ssl-offloading-https-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-04
  rules:
  - backendRefs:
    - name: echo
      port: 80
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show HTTPRoute YAML manifest
kubectl get httproute ssl-offloading-https-route -n test-infra -o yaml