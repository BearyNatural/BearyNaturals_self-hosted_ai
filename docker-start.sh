#!/bin/bash

set -e

# --- ENVIRONMENT VARIABLES ---
export POSTGRES_USER=n8n
export POSTGRES_PASSWORD=n8npass
export POSTGRES_DB=n8n

# --- CREATE VOLUMES ---
docker volume create postgres_storage
docker volume create n8n_storage
docker volume create qdrant_storage

# --- CREATE NETWORK ---
docker network create demo || true

# --- START POSTGRES ---
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

# --- IMPORT CREDENTIALS ---
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
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -e N8N_RUNNERS_ENABLED=true \
  -v ./n8n/backup:/backup \
  n8nio/n8n:latest \
  import:credentials --separate --input=/backup/credentials

# --- IMPORT WORKFLOWS ---
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
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -v ./n8n/backup:/backup \
  n8nio/n8n:latest \
  import:workflow --separate --input=/backup/workflows

# --- START QDRANT ---
docker run -d --name qdrant \
  --hostname qdrant \
  --network demo \
  --restart unless-stopped \
  -p 6333:6333 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant

# --- START N8N SERVER ---
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
  -e OLLAMA_HOST=host.docker.internal:11434 \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -v n8n_storage:/home/node/.n8n \
  -v ./n8n/backup:/backup \
  -v ./shared:/data/shared \
  n8nio/n8n:latest

# Start Cloudflare Tunnel in the background
cloudflared tunnel run n8n-tunnel 

echo ""
echo "All services are up and running!"
echo "Open n8n in your browser: http://localhost:5678"
echo "Update the 'Local Ollama Service' credential to: http://host.docker.internal:11434/"
