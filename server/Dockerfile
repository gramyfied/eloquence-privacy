# Étape 1 : Image Kaldi officielle (pré-compilée)
FROM kaldiasr/kaldi:latest as kaldi-builder

# Étape 2 : Image finale Node.js
FROM node:18

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    git \
    cmake \
    python3 \
    python3-pip \
    ffmpeg \
    libsndfile1 \
    libopenblas-dev \
    pkg-config \
    sox \
    libatlas-base-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier les binaires et bibliothèques Kaldi/OpenFST depuis l'image officielle
COPY --from=kaldi-builder /opt/kaldi /opt/kaldi
COPY --from=kaldi-builder /usr/local/lib/libfst* /usr/local/lib/

RUN ldconfig

# Copier les binaires Kaldi utiles (exemple : compute-gop, text-to-phonemes)
COPY --from=kaldi-builder /opt/kaldi/src/bin/compute-gop /usr/local/bin/

# (Suppression de toute recompilation ou configuration Kaldi : l'image officielle suffit)

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

WORKDIR /app
RUN mkdir -p /app/models/whisper \
    /app/models/piper \
    /app/models/kaldi \
    /app/models/llm

# Copier les fichiers du projet
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Changer le propriétaire des fichiers
RUN chown -R node:node /app

USER node

EXPOSE 3000

CMD ["npm", "start"]
