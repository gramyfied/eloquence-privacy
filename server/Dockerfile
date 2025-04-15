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
    gfortran \
    automake \
    autoconf \
    unzip \
    sox \
    libtool \
    python-is-python3 \
    zlib1g-dev \
    subversion \
    libfst-dev \
    libfst-tools \
    libatlas-base-dev \
    liblapack-dev \
    liblapacke-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer Node.js 18.x et npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
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
    && cp build/bin/whisper-cli /usr/local/bin/whisper \
    && rm -rf /tmp/whisper.cpp

# Installer Piper
RUN git clone https://github.com/rhasspy/piper.git /tmp/piper \
    && cd /tmp/piper \
    && make \
    && cp /tmp/piper/install/piper /usr/local/bin/ \
    && rm -rf /tmp/piper

# Installation de Kaldi avec GOP
RUN apt-get update && apt-get install -y \
    zlib1g-dev \
    automake \
    autoconf \
    libtool \
    subversion \
    wget \
    python3-dev \
    python3-pip \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /tmp/kaldi \
    && cd /tmp/kaldi/tools \
    && mkdir -p python \
    && ln -sf $(which python3) python/python3 \
    && ln -sf $(which python3) python/python \
    && extras/install_openblas.sh \
    && wget -O openfst-1.8.4.tar.gz https://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.8.4.tar.gz \
    && tar -xzf openfst-1.8.4.tar.gz \
    && cd openfst-1.8.4 \
    && ./configure --enable-shared --enable-far --enable-ngram-fsts --enable-lookahead-fsts --enable-const-fsts --enable-pdt --enable-linear-fsts --prefix=/usr/local \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd /tmp/kaldi/src \
    && ./configure --shared --use-cuda=no --fst-root=/usr/local \
    && make -j$(nproc) depend \
    && make -j$(nproc) online2 lm rnnlm \
    && cd /tmp/kaldi/src/gop \
    && make -j$(nproc) \
    && cd /tmp/kaldi/src/bin \
    && make -j$(nproc) compute-gop \
    && cd /tmp/kaldi/src/featbin \
    && make -j$(nproc) \
    && cd /tmp/kaldi/src/gmmbin \
    && make -j$(nproc) \
    && cd /tmp/kaldi/src/latbin \
    && make -j$(nproc) \
    && mkdir -p /opt/kaldi/bin \
    && cp /tmp/kaldi/src/bin/compute-gop /opt/kaldi/bin/ \
    && cp /tmp/kaldi/src/featbin/compute-mfcc-feats /opt/kaldi/bin/ \
    && cp /tmp/kaldi/src/gmmbin/gmm-* /opt/kaldi/bin/ \
    && cp /tmp/kaldi/src/latbin/lattice-* /opt/kaldi/bin/ \
    && ln -sf /opt/kaldi/bin/compute-gop /usr/local/bin/compute-gop \
    && rm -rf /tmp/kaldi

# Installer llama.cpp
RUN git clone https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
    && cd /tmp/llama.cpp \
    && make \
    && cp /tmp/llama.cpp/main /usr/local/bin/llama-chat \
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

# Ajouter un healthcheck pour vérifier que le serveur est en cours d'exécution
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
