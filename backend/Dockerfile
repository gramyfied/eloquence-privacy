# Dockerfile pour l'API Backend Eloquence
FROM python:3.11-slim

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Répertoire de travail
WORKDIR /app

# Installation des dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install LiveKit CLI manually to ensure it's in PATH
RUN curl -L -o livekit.tar.gz "https://github.com/livekit/livekit/releases/download/v1.9.0/livekit_1.9.0_linux_amd64.tar.gz" && \
    tar -zxvf livekit.tar.gz && \
    mv livekit-server /usr/local/bin/lk && \
    rm livekit.tar.gz

# Ensure livekit CLI is in PATH for subsequent commands (redundant but safe)
ENV PATH="/usr/local/bin:$PATH"

# Verify livekit CLI installation
RUN lk version --client

# Copie des fichiers de requirements
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code de l'application
COPY . .

# Exposition du port
EXPOSE 8000

# Commande de démarrage avec WSGI
CMD ["python", "wsgi.py"]