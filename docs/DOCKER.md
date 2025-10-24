# DOCKER: DeepSeek‑OCR + RAG‑Anything — Build & Run

> **Note:** The standalone `docker-compose.deepseek-rag.yml` has been archived to
> `.archive/docker-compose/`. These services are now part of the unified stack orchestrated by
> `compose.gateway.yaml` (via `scripts/up_stack.sh`). See [docs/CONTAINERS.md](../CONTAINERS.md) and
> [DOCKER.md](../../DOCKER.md) for the current deployment approach.

This document describes how to build and run container images for DeepSeek‑OCR and RAG‑Anything,
sample environment variables, VRAM/hardware notes, and example image tags.

Supported images & example tags

- myorg/deepseek-ocr:1.0.0-gpu11.8 (DeepSeek‑OCR runtime image — GPU variant)
- myorg/rag-anything:1.0.0 (RAG‑Anything service image)

Build (local)

```powershell
# Build DeepSeek OCR image
docker build -t myorg/deepseek-ocr:1.0.0-gpu11.8 services/deepseek-ocr

# Build RAG-Anything image
docker build -t myorg/rag-anything:1.0.0 services/rag-anything
```

Docker Compose (unified stack)

These services are now defined in `compose.gateway.yaml` and launched via the modular stack helper:

```bash
# Start the complete stack (gateway, DeepSeek OCR, RAG, embeddings, Qdrant, MinIO, etc.)
./scripts/up_stack.sh
```

For reference, the unified compose definitions look like:

```yaml
version: '3.9'
services:
  deepseek-ocr:
    image: myorg/deepseek-ocr:1.0.0-gpu11.8
    restart: unless-stopped
    ports:
      - '127.0.0.1:11434:11434' # or map host different port if conflict
    volumes:
      - ./models/deepseek:/models:ro
    environment:
      - MODEL_DIR=/models
      - VRAM_PROFILE=${VRAM_PROFILE:-12GB}
    healthcheck:
      test: ['CMD', 'curl', '-f', 'http://localhost:11434/healthz']

  rag:
    image: myorg/rag-anything:1.0.0
    restart: unless-stopped
    ports:
      - '8082:8082'
    environment:
      - VECTOR_URL=${VECTOR_URL:-http://qdrant:6333}
      - EMBEDDINGS_URL=${EMBEDDINGS_URL:-http://embeddings:8080}
      - DEEPSEEK_OCR_URL=${DEEPSEEK_OCR_URL:-http://deepseek-ocr:11434}
    depends_on:
      - deepseek-ocr
```

Environment variables (examples)

- VRAM_PROFILE — preset name controlling batch-size and resolution. Example values: `8GB`, `12GB`,
  `16GB`.
- DEEPSEEK_MODEL_PATH — path inside container where model weights live (mounted from host/MinIO).
- EMBEDDINGS_URL, VECTOR_URL — endpoints for embeddings service and vector DB.
- MINIO_ENDPOINT / MINIO_ACCESS_KEY / MINIO_SECRET_KEY — object store for model weights.

Notes on model weights

- DO NOT commit model weight files into Git. Store weights in MinIO or external object storage.
- For model license compliance, include `LICENSE-MODEL.md` in the repo root with a copy or pointer
  to the DeepSeek model license and any usage constraints.

VRAM profiles and tuning

- VRAM_PROFILE selects conservative defaults for batch size and image resolution.
- Example mapping (document in README):
  - 8GB: downscale images to 1024px, batch size 1
  - 12GB: 1536px, batch size 2
  - 16GB+: full resolution, batch size 4

Health checks

- DeepSeek‑OCR should expose `/healthz` returning 200 when ready.
- RAG‑Anything should expose `/healthz` and `/v1/ingest` and `/v1/query` for functional tests.

Quick local test (PowerShell)

```powershell
# Start the unified stack (includes DeepSeek OCR, RAG, embeddings, Qdrant, MinIO, etc.)
./scripts/up_stack.sh
# Or on Windows:
.\scripts\up_stack.ps1

# Wait and then test basic health endpoints
Invoke-WebRequest -UseBasicParsing http://localhost:8081/healthz  # DeepSeek OCR via Traefik
Invoke-WebRequest -UseBasicParsing http://localhost:8082/healthz  # RAG Anything
```

Versioning & tags

- Use semantic versioning for image tags, include GPU/runtime indicator when relevant:
  `myorg/deepseek-ocr:1.0.0-gpu11.8`.
- Create matching Git tags/releases in your fork for traceability.

CI notes (summary)

- CI job should build both images, run them in a small docker host or GitHub Actions service
  container, and execute a tiny inference test (one image document through DeepSeek‑OCR to RAG
  ingest + query).
