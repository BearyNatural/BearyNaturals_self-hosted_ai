#!/bin/bash

echo "Stopping and removing containers..."

docker rm -f n8n || true
docker rm -f n8n-import || true
docker rm -f qdrant || true
docker rm -f postgres || true
docker rm -f ollama || true
docker rm -f ollama-pull-llama || true

echo "Removing volumes..."

docker volume rm n8n_storage || true
docker volume rm postgres_storage || true
docker volume rm qdrant_storage || true
docker volume rm ollama_storage || true

echo "Removing network..."

docker network rm demo || true

echo "Cleanup complete."
