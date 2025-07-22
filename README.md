# gRPC Delay + Forward Service

A minimal Python gRPC service for chained request testing, latency simulation, and multi-hop behavior modeling in Kubernetes or OpenShift.

It exposes a `HelloService` with a single `SayHello` method that can:

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

The service is configured entirely via environment variables:

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
```
### Create namespace
oc new-project ns-a

### Create a new binary build from your local directory (must include Dockerfile, hello.proto, server.py)
oc new-build --binary --name=grpc-delay-server -l app=grpc-delay-server
oc start-build grpc-delay-server --from-dir=. --follow
oc new-app grpc-delay-server

### Set environment variables (change as needed for ns-b and ns-c)
## For ns-b: use LISTEN_PORT=50052 and FORWARD_HOST=grpc-delay-c.ns-c.svc.cluster.local, FORWARD_PORT=50053
# For ns-c (final hop): use LISTEN_PORT=50053 and omit FORWARD_HOST and FORWARD_PORT entirely

oc set env deployment/grpc-delay-server LISTEN_PORT=50051 DELAY_MS=1000 FORWARD_HOST=grpc-delay-b.ns-b.svc.cluster.local FORWARD_PORT=50052
oc expose deployment grpc-delay-server --port=50051 --name=grpc-delay-server
```
---
## Example Chained Setup

You can deploy the same image in multiple namespaces with different behavior:

- `ns-a`: forwards to `grpc-delay-b.ns-b.svc.cluster.local:50052`
- `ns-b`: forwards to `grpc-delay-c.ns-c.svc.cluster.local:50053`
- `ns-c`: final responder, no forwarding

---

## Testing with grpcurl
```
oc port-forward svc/grpc-delay-server 50051:50051 -n ns-a
grpcurl -plaintext -import-path . -proto hello.proto -d '{"name":"Alice"}' localhost:50051 hello.HelloService/SayHello
```

