#!/bin/bash

# Create two HTTPRoute resources for contoso.com and fabrikam.com domain names. Each domain forwards traffic to a different backend service.
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: contoso-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-02
  hostnames:
  - "contoso.com"
  rules:
  - backendRefs:
    - name: backend-v1
      port: 8080
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: fabrikam-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-02
  hostnames:
  - "fabrikam.com"
  rules:
  - backendRefs:
    - name: backend-v2
      port: 8080
EOF

# Wait 10 seconds
echo "Waiting 10 seconds..."
sleep 10

# Show HTTPRoute YAML manifest
kubectl get httproute contoso-route -n test-infra -o yaml
kubectl get httproute fabrikam-route -n test-infra -o yaml