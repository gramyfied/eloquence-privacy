FROM ubuntu:22.04 AS kaldi-base

# Éviter les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances de base
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    wget \
    automake \
    autoconf \
    libtool \
    subversion \
    python3 \
    python3-pip \
    python-is-python3 \
    zlib1g-dev \
    libatlas-base-dev \
    liblapack-dev \
    liblapacke-dev \
    gfortran \
    && rm -rf /var/lib/apt/lists/*

# Étape 1: Installation de Kaldi avec OpenFST compilé à partir des sources
FROM kaldi-base AS kaldi-builder

# Cloner Kaldi (avec --depth 1 pour accélérer)
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi-src

# Configurer les liens symboliques Python
RUN cd /opt/kaldi-src/tools \
    && mkdir -p python \
    && ln -sf $(which python3) python/python3 \
    && ln -sf $(which python3) python/python

# Installer OpenBLAS
RUN cd /opt/kaldi-src/tools \
    && ./extras/install_openblas.sh

# Installer OpenFST à partir des sources (version compatible)
RUN cd /opt/kaldi-src/tools \
    && wget -O openfst-1.8.4.tar.gz https://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.8.4.tar.gz \
    && tar -xzf openfst-1.8.4.tar.gz \
    && cd openfst-1.8.4 \
    && ./configure --enable-shared --enable-far --enable-ngram-fsts --enable-lookahead-fsts --enable-const-fsts --enable-pdt --enable-linear-fsts --prefix=/usr/local \
    && make -j$(nproc) \
    && make install \
    && ldconfig

# Configurer et compiler Kaldi (uniquement les outils nécessaires)
RUN cd /opt/kaldi-src/src \
    && ./configure --shared --use-cuda=no \
    && make -j$(nproc) depend \
    && cd bin \
    && make -j$(nproc) compute-gop text-to-phonemes

# Image finale
FROM ubuntu:22.04

# Éviter les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances nécessaires pour l'exécution
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    cmake \
    build-essential \
    python3 \
    python3-pip \
    ffmpeg \
    libsndfile1 \
    libopenblas-dev \
    pkg-config \
    sox \
    libatlas-base-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer Node.js 18.x et npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
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

# Installer Whisper.cpp (avec --depth 1 pour accélérer)
RUN git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp \
    && cd /tmp/whisper.cpp \
    && make \
    && cp build/bin/whisper-cli /usr/local/bin/whisper \
    && rm -rf /tmp/whisper.cpp

# Installer Piper (avec --depth 1 pour accélérer)
RUN git clone --depth 1 https://github.com/rhasspy/piper.git /tmp/piper \
    && cd /tmp/piper \
    && make \
    && cp /tmp/piper/install/piper /usr/local/bin/ \
    && rm -rf /tmp/piper

# Copier les bibliothèques OpenFST depuis l'étape de construction
COPY --from=kaldi-builder /usr/local/lib/libfst* /usr/local/lib/
COPY --from=kaldi-builder /usr/local/lib/fst /usr/local/lib/fst
COPY --from=kaldi-builder /usr/local/include/fst /usr/local/include/fst

# Mettre à jour le cache des bibliothèques dynamiques
RUN ldconfig

# Copier les binaires Kaldi compilés depuis l'étape précédente
COPY --from=kaldi-builder /opt/kaldi-src/src/bin/compute-gop /usr/local/bin/
COPY --from=kaldi-builder /opt/kaldi-src/src/bin/text-to-phonemes /usr/local/bin/

# Installer llama.cpp (avec --depth 1 pour accélérer)
RUN git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
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
