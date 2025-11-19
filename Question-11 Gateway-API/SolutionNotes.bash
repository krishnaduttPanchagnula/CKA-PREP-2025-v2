# Step 1
# Verify secret and ingress exist and describe them
k get secret
k describe secret web-tls
k get ingress
k describe ingress web

# Step 2
# Create the Gateway (use the docs)
vi gw.yaml
#yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
spec:
  gatewayClassName: nginx-class
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: gateway.web.k8s.local
    tls:                              # This is the section we need to add to maintain the existing config
      mode: Terminate                 # for the ingress resource
      certificateRefs:
       - kind: Secret
         name: web-tls
# Apply it
k apply -f gw.yaml
# Check it is there
k get gateway

# Step 3 create the HTTPRoute
vi http.yaml
# Use the docs for reference
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - "gateway.web.k8s.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /                  # We see the path from the ingress description
    backendRefs:
    - name: web-service           # Name and port need to match the service we have
      port: 80.
# apply it
k apply -f http.yaml

# Check
k describe gateway,httproute

# Check all fields match as expected. In the exam you may be given a curl to run to check this
