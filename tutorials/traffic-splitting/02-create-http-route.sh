#!/bin/bash

# Create an HTTPRoute that sends 50% of the traffic to backend-v1 and 50% to backend-v2
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: traffic-split-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-05
  rules:
  - backendRefs:
    - name: backend-v1
      port: 8080
      weight: 50
    - name: backend-v2
      port: 8080
      weight: 50
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show HTTPRoute YAML manifest
kubectl get httproute traffic-split-route -n test-infra -o yaml