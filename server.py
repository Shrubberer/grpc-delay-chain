import os
import time
import grpc
from concurrent import futures
import hello_pb2
import hello_pb2_grpc

DELAY_MS = int(os.getenv("DELAY_MS", "0"))
FORWARD_HOST = os.getenv("FORWARD_HOST", "").strip()
FORWARD_PORT = os.getenv("FORWARD_PORT", "").strip()
LISTEN_PORT = int(os.getenv("LISTEN_PORT", "50051"))
HOSTNAME = os.getenv("HOSTNAME", "unknown")

class HelloService(hello_pb2_grpc.HelloServiceServicer):
    def SayHello(self, request, context):
        print(f"[{HOSTNAME}] Received request: name = {request.name}")

        if DELAY_MS > 0:
            print(f"[{HOSTNAME}] Delaying for {DELAY_MS} ms")
            time.sleep(DELAY_MS / 1000.0)

        if FORWARD_HOST and FORWARD_PORT:
            target = f"{FORWARD_HOST}:{FORWARD_PORT}"
            print(f"[{HOSTNAME}] Forwarding request to {target}")
            channel = grpc.insecure_channel(target)
            stub = hello_pb2_grpc.HelloServiceStub(channel)
            response = stub.SayHello(request)
            print(f"[{HOSTNAME}] Received response from downstream")
            return response
        else:
            response_msg = f"Hello from {HOSTNAME}, {request.name}!"
            print(f"[{HOSTNAME}] Responding locally with: {response_msg}")
            return hello_pb2.HelloReply(message=response_msg)

def serve():
    print(f"[{HOSTNAME}] Starting gRPC server on port {LISTEN_PORT}")
    if FORWARD_HOST and FORWARD_PORT:
        print(f"[{HOSTNAME}] Forwarding is enabled → {FORWARD_HOST}:{FORWARD_PORT}")
    else:
        print(f"[{HOSTNAME}] No forwarding configured. Will respond directly.")

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    hello_pb2_grpc.add_HelloServiceServicer_to_server(HelloService(), server)
    server.add_insecure_port(f"[::]:{LISTEN_PORT}")
    server.start()
    server.wait_for_termination()

if __name__ == "__main__":
    serve()
