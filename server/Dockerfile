FROM ubuntu:22.04

# Éviter les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    ffmpeg \
    libsndfile1 \
    libopenblas-dev \
    pkg-config \
    # nodejs et npm seront installés via NodeSource
    && rm -rf /var/lib/apt/lists/*

# Installer Node.js 18.x et npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root
RUN useradd -m -s /bin/bash appuser

# Créer les répertoires de travail
WORKDIR /app
RUN mkdir -p /app/models/whisper \
    /app/models/piper \
    /app/models/kaldi \
    /app/models/llm \
    && chown -R appuser:appuser /app

# Installer Whisper.cpp
RUN git clone https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp \
    && cd /tmp/whisper.cpp \
    && make \
    && cp main /usr/local/bin/whisper \
    && rm -rf /tmp/whisper.cpp

# Installer Piper
RUN git clone https://github.com/rhasspy/piper.git /tmp/piper \
    && cd /tmp/piper \
    && make \
    && cp piper /usr/local/bin/ \
    && rm -rf /tmp/piper

# Installer Kaldi GOP
RUN git clone https://github.com/kaldi-asr/kaldi.git /tmp/kaldi \
    && cd /tmp/kaldi/tools \
    && extras/install_openblas.sh \
    && make -j$(nproc) \
    && cd /tmp/kaldi/src \
    && ./configure --shared --use-cuda=no \
    && make -j$(nproc) depend \
    && make -j$(nproc) \
    && cp /tmp/kaldi/src/bin/compute-gop /usr/local/bin/ \
    && cp /tmp/kaldi/src/bin/text-to-phonemes /usr/local/bin/ \
    && rm -rf /tmp/kaldi

# Installer llama.cpp
RUN git clone https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
    && cd /tmp/llama.cpp \
    && make \
    && cp main /usr/local/bin/llama-chat \
    && rm -rf /tmp/llama.cpp

# Copier les fichiers du projet
COPY package*.json ./
RUN npm ci

# Copier le reste des fichiers
COPY . .

# Changer le propriétaire des fichiers
RUN chown -R appuser:appuser /app

# Passer à l'utilisateur non-root
USER appuser

# Exposer le port
EXPOSE 3000

# Commande de démarrage
CMD ["npm", "start"]
