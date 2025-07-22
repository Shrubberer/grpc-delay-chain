FROM python:3.11-slim

WORKDIR /app
COPY . .

RUN pip install grpcio grpcio-tools

RUN python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. hello.proto

ENV PYTHONUNBUFFERED=1

CMD ["python", "server.py"]
