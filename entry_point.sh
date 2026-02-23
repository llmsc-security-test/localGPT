#!/bin/bash
# entry_point.sh - Entry point script for localGPT Docker container
# Starts long-running HTTP services for backend (8000) and RAG API (8001)

set -e

echo "============================================"
echo "  localGPT Docker Container Entry Point"
echo "============================================"

# Create necessary directories
mkdir -p /app/shared_uploads /app/logs /app/index_store /app/lancedb

# Set PYTHONPATH if not already set
export PYTHONPATH=${PYTHONPATH:-/app}

# Wait for Ollama if HOST_DOCKER_INTERNAL is available
echo "Waiting for Ollama at ${OLLAMA_HOST:-http://host.docker.internal:11434}..."

MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "${OLLAMA_HOST:-http://host.docker.internal:11434}/api/tags" > /dev/null 2>&1; then
        echo "✅ Ollama is available"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Waiting for Ollama... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  Ollama not available, continuing anyway (may need to add models manually)"
fi

# Start RAG API server on port 8001 in background
echo "Starting RAG API server on port 8001..."
cd /app
python -m rag_system.api_server &
RAG_API_PID=$!

# Small delay to ensure RAG API starts
sleep 3

# Start backend server on port 8000
echo "Starting backend server on port 8000..."
cd /app/backend
python server.py &
BACKEND_PID=$!

echo ""
echo "============================================"
echo "  localGPT Services Started"
echo "============================================"
echo "  Backend Server (HTTP): http://localhost:8000"
echo "    - Chat endpoint:      http://localhost:8000/chat"
echo "    - Health check:       http://localhost:8000/health"
echo "    - Sessions:           http://localhost:8000/sessions"
echo ""
echo "  RAG API Server (HTTP): http://localhost:8001"
echo "    - Chat endpoint:      http://localhost:8001/chat"
echo "    - Index endpoint:     http://localhost:8001/index"
echo "    - Models:             http://localhost:8001/models"
echo "============================================"
echo ""

# Keep script running by waiting for background processes
wait $BACKEND_PID
