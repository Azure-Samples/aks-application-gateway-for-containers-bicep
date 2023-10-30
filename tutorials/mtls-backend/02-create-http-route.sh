#!/bin/bash

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: https-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - backendRefs:
    - name: mtls-app
      port: 443
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show HTTPRoute YAML manifest
kubectl get httproute https-route -n test-infra -o yaml