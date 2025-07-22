#!/bin/bash

# === Configuration per namespace
NAMESPACES=("ns-a" "ns-b" "ns-c")
PORTS=(50051 50052 50053)
FORWARD_HOSTS=("grpc-delay-server.ns-b.svc.cluster.local" "grpc-delay-server.ns-c.svc.cluster.local" "")
FORWARD_PORTS=(50052 50053 "")
IDENTITIES=("hop-a" "hop-b" "hop-c")

echo "This script will deploy the gRPC delay service into the following namespaces in your current OpenShift cluster:"
for ns in "${NAMESPACES[@]}"; do
  echo "  • $ns"
done

read -p "Proceed with deployment? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted by user."
  exit 1
fi

for i in "${!NAMESPACES[@]}"; do
  NS="${NAMESPACES[$i]}"
  LISTEN_PORT="${PORTS[$i]}"
  FORWARD_HOST="${FORWARD_HOSTS[$i]}"
  FORWARD_PORT="${FORWARD_PORTS[$i]}"
  IDENTITY="${IDENTITIES[$i]}"

  echo "Setting up namespace: $NS"
  oc new-project "$NS" || oc project "$NS"

  echo "Creating build and app in $NS"
  oc new-build --binary --name=grpc-delay-server -l app=grpc-delay-server
  oc start-build grpc-delay-server --from-dir=. --follow
  oc new-app grpc-delay-server -l app=grpc-delay-server

  echo "⚙️  Setting environment variables in $NS"
  oc set env deployment/grpc-delay-server LISTEN_PORT="$LISTEN_PORT" DELAY_MS=1000 IDENTITY="$IDENTITY"

  if [[ -n "$FORWARD_HOST" && -n "$FORWARD_PORT" ]]; then
    oc set env deployment/grpc-delay-server FORWARD_HOST="$FORWARD_HOST" FORWARD_PORT="$FORWARD_PORT"
  fi

  echo "Exposing service on port $LISTEN_PORT"
  oc expose deployment grpc-delay-server --port="$LISTEN_PORT" --name=grpc-delay-server

  echo "$NS is ready!"
  echo ""
done
