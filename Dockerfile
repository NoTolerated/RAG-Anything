FROM python:3.11-slim

ARG FULL=0
WORKDIR /app

# Install minimal system deps (add as needed for image processing / model runtimes)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1 \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and application code
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Optional full runtime dependencies (installed when building with --build-arg FULL=1)
RUN if [ "$FULL" = "1" ] ; then \
    pip install --no-cache-dir torch torchvision torchaudio sentence-transformers pytesseract qdrant-client; \
    fi

COPY server.py ./

ENV DEEPSEEK_MODEL_PATH=/models/deepseek
EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD curl -f http://localhost:11434/healthz || exit 1

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "11434"]
