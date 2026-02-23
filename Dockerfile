# Unified Dockerfile for localGPT
# This container includes the backend server (port 8000) and RAG API server (port 8001)
# Ollama must be connected via host network or external container

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements-docker.txt ./requirements-docker.txt
# Copy rag_system requirements and filter out ocrmac (macOS-specific)
COPY rag_system/requirements.txt ./rag_system_requirements.txt
RUN grep -v "ocrmac" rag_system_requirements.txt > rag_system_requirements_filtered.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements-docker.txt
RUN pip install --no-cache-dir -r rag_system_requirements_filtered.txt

# Copy application code
COPY backend/ ./backend/
COPY rag_system/ ./rag_system/

# Create necessary directories
RUN mkdir -p shared_uploads logs index_store lancedb

# Set environment variables
ENV PYTHONPATH=/app
ENV OLLAMA_HOST=${OLLAMA_HOST:-http://host.docker.internal:11434}

# Expose ports for backend (8000) and RAG API (8001)
EXPOSE 8000 8001

# Health check - checks backend server
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run both backend and RAG API servers
CMD ["bash", "-c", "cd /app/backend && python server.py & cd /app && python -m rag_system.api_server"]
