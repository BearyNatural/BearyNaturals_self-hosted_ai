#!/bin/bash

set -e

# --- ENVIRONMENT VARIABLES ---
export POSTGRES_USER=n8n
export POSTGRES_PASSWORD=n8npass
export POSTGRES_DB=n8n

# --- UPDATE IMAGES ---
echo "Pulling latest Docker images..."
docker pull postgres:16-alpine
docker pull qdrant/qdrant:latest
docker pull n8nio/n8n:latest

# --- STOP AND REMOVE OLD CONTAINERS ---
echo "Stopping and removing existing containers (not volumes)..."
docker rm -f n8n || true
docker rm -f n8n-import-creds || true
docker rm -f n8n-import-workflows || true
docker rm -f qdrant || true
docker rm -f postgres || true

# --- RECREATE NETWORK IF NEEDED ---
docker network inspect demo >/dev/null 2>&1 || docker network create demo

# --- START POSTGRES ---
echo "Starting PostgreSQL..."
docker run -d --name postgres \
  --hostname postgres \
  --network demo \
  --restart unless-stopped \
  -e POSTGRES_USER=$POSTGRES_USER \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e POSTGRES_DB=$POSTGRES_DB \
  -v postgres_storage:/var/lib/postgresql/data \
  postgres:16-alpine

echo "Waiting 10 seconds for PostgreSQL to initialize..."
sleep 10

# --- IMPORT CREDENTIALS (if needed) ---
echo "Importing credentials..."
docker run --rm --name n8n-import-creds \
  --hostname n8n-import-creds \
  --network demo \
  --env-file .env \
  --entrypoint n8n \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_USER=$POSTGRES_USER \
  -e DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD \
  -e N8N_DIAGNOSTICS_ENABLED=false \
  -e N8N_PERSONALIZATION_ENABLED=false \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -v ./n8n/backup:/backup \
  n8nio/n8n:latest \
  import:credentials --separate --input=/backup/credentials

# --- IMPORT WORKFLOWS (if needed) ---
echo "Importing workflows..."
docker run --rm --name n8n-import-workflows \
  --hostname n8n-import-workflows \
  --network demo \
  --env-file .env \
  --entrypoint n8n \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_USER=$POSTGRES_USER \
  -e DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD \
  -e N8N_DIAGNOSTICS_ENABLED=false \
  -e N8N_PERSONALIZATION_ENABLED=false \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -v ./n8n/backup:/backup \
  n8nio/n8n:latest \
  import:workflow --separate --input=/backup/workflows

# --- START QDRANT ---
echo "Starting Qdrant..."
docker run -d --name qdrant \
  --hostname qdrant \
  --network demo \
  --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant

# --- START n8n ---
echo "Starting n8n server..."
docker run -d --name n8n \
  --hostname n8n \
  --network demo \
  --restart unless-stopped \
  -p 5678:5678 \
  --env-file .env \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=postgres \
  -e DB_POSTGRESDB_USER=$POSTGRES_USER \
  -e DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD \
  -e N8N_DIAGNOSTICS_ENABLED=false \
  -e N8N_PERSONALIZATION_ENABLED=false \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -v n8n_storage:/home/node/.n8n \
  -v ./n8n/backup:/backup \
  -v ./shared:/data/shared \
  n8nio/n8n:latest

echo ""
echo "All services updated and running!"
echo "Open n8n: http://localhost:5678"
echo "Make sure your Ollama credential points to: http://host.docker.internal:11434/"
