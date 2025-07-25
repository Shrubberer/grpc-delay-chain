# gRPC Delay + Forward Service

A minimal Python gRPC service for chained request testing, latency simulation, and multi-hop behavior modeling in OpenShift.
But why not use a ready made tool like grpcbin? 
...well the images I tried out did not have a delay option - so in this particular case re-inventing the wheel was faster.

So this basic grpc server exposes a `HelloService` with a single `SayHello` method that can:
- Respond immediately
- Add an artificial delay
- Forward the request to another gRPC service and return the downstream response

This makes it ideal for testing chained service topologies like `A → B → C`.
Upon receiving a `SayHello` request, the service:

1. Optionally delays its response (`DELAY_MS`)
2. If both `FORWARD_HOST` and `FORWARD_PORT` are set, forwards the request to the target gRPC service
3. Otherwise, replies directly with a greeting

---

##
Configuration

The service is configured via environment variables:

| Variable        | Default   | Description                                           |
|----------------|-----------|-------------------------------------------------------|
| `LISTEN_PORT`   | `50051`   | Port on which the gRPC server listens                 |
| `DELAY_MS`      | `0`       | Optional delay in milliseconds before responding      |
| `FORWARD_HOST`  | *(unset)* | Target hostname for forwarding the request            |
| `FORWARD_PORT`  | *(unset)* | Target port for forwarding the request                |

- If `FORWARD_HOST` and `FORWARD_PORT` are unset, the service replies directly.
- If both are set, it forwards the request and returns the response from the downstream service.

---
## Installation
1) connect to openshift cluster
2) run install.sh


...or if really needed, install manually (e.g. if you want to customize)
```
Manual installation 
# === Create projects (replace ns-a with ns-b or ns-c as needed)
oc new-project ns-a

# === Create binary build from your local source (Dockerfile, hello.proto, server.py must be present)
oc new-build --binary --name=grpc-delay-server -l app=grpc-delay-server
oc start-build grpc-delay-server --from-dir=. --follow
oc new-app grpc-delay-server -l app=grpc-delay-server

# === Set environment variables (adjust LISTEN_PORT and FORWARD targets based on namespace)
# Example for ns-a (forwards to ns-b)
oc set env deployment/grpc-delay-server LISTEN_PORT=50051 DELAY_MS=1000 FORWARD_HOST=grpc-delay-server.ns-b.svc.cluster.local FORWARD_PORT=50052

# Example for ns-b (forwards to ns-c)
# oc set env deployment/grpc-delay-server LISTEN_PORT=50052 DELAY_MS=1000 FORWARD_HOST=grpc-delay-server.ns-c.svc.cluster.local FORWARD_PORT=50053

# Example for ns-c (final hop, no forwarding)
# oc set env deployment/grpc-delay-server LISTEN_PORT=50053 DELAY_MS=1000

# === Expose the deployment as a service (must match LISTEN_PORT)
oc expose deployment grpc-delay-server --port=50051 --name=grpc-delay-server
# For ns-b use: oc expose deployment grpc-delay-server --port=50052 --name=grpc-delay-server
# For ns-c use: oc expose deployment grpc-delay-server --port=50053 --name=grpc-delay-server

```
---
## Example Chained Setup

You can deploy the same image in multiple namespaces with different behavior:

- `ns-a`: forwards to `grpc-delay-b.ns-b.svc.cluster.local:50052`
- `ns-b`: forwards to `grpc-delay-c.ns-c.svc.cluster.local:50053`
- `ns-c`: final responder, no forwarding

---

# Testing

## Testing with grpcurl
```
# Suggested quick set up: Two terminals
# 1) For grpcurl and port-forwarding: Use the tmux bash script (tmux-grpc.sh) tool to quickly create panes, port-forward and log following
# 2) For istio sidecars: follow istio-proxy logs. For example, if json access logs are enabled:
oc logs $(oc get pod -l app=grpc-delay-server -n ns-a -o jsonpath='{.items[0].metadata.name}') -f -n ns-a | grep --line-buffered '^{' | jq .
oc logs $(oc get pod -l app=grpc-delay-server -n ns-b -o jsonpath='{.items[0].metadata.name}') -f -n ns-b | grep --line-buffered '^{' | jq .
oc logs $(oc get pod -l app=grpc-delay-server -n ns-c -o jsonpath='{.items[0].metadata.name}') -f -n ns-c

#
# ...or else (manually, without tmux):
# port forward in three terminals (or panes)
# NOTE: define the namespace, it is *not* redundant if you use termninal panes

oc port-forward svc/grpc-delay-server 50051:50051 -n ns-a
oc port-forward svc/grpc-delay-server 50051:50051 -n ns-b
oc port-forward svc/grpc-delay-server 50051:50051 -n ns-c
# follow logs for each namespace
oc logs $(oc get pod -l app=grpc-delay-server -o jsonpath='{.items[0].metadata.name}') -f -n ns-a
oc logs $(oc get pod -l app=grpc-delay-server -o jsonpath='{.items[0].metadata.name}') -f -n ns-b
oc logs $(oc get pod -l app=grpc-delay-server -o jsonpath='{.items[0].metadata.name}') -f -n ns-c

grpcurl -plaintext -import-path . -proto hello.proto -d '{"name":"Shrubber"}' localhost:50051 hello.HelloService/SayHello
```
## Adding Istio Service Mesh
```
# First make sure to add the namespace in smmr
oc edit smmr -n istio-system

# Add annotation to deployments
for ns in ns-a ns-b ns-c; do
  oc patch deployment grpc-delay-server -n "$ns" --type='strategic' -p='{"spec":{"template":{"metadata":{"annotations":{"sidecar.istio.io/inject":"true"}}}}}'
done

# add virtual services 
oc apply -f vs.yaml

# Enable access logs in smcp or with telemetry - eg:
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  proxy:
    accessLogging:
      file:
        name: /dev/stdout 


```

