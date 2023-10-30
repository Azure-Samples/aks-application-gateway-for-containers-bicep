#!/bin/bash

kubectl apply -f - <<EOF
apiVersion: alb.networking.azure.io/v1
kind: BackendTLSPolicy
metadata:
  name: mtls-app-tls-policy
  namespace: test-infra
spec:
  targetRef:
    group: ""
    kind: Service
    name: mtls-app
    namespace: test-infra
  default:
    sni: backend.com
    ports:
    - port: 443
    clientCertificateRef:
      name: gateway-client-cert
      group: ""
      kind: Secret
    verify:
      caCertificateRef:
        name: ca.bundle
        group: ""
        kind: Secret
      subjectAltName: backend.com
EOF

# Once the BackendTLSPolicy object has been create check the status on the object to ensure that the policy is valid
kubectl get backendtlspolicy -n test-infra mtls-app-tls-policy -o yaml