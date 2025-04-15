# Étape 1 : Compilation Kaldi sur Ubuntu
FROM ubuntu:22.04 AS kaldi-base
ENV DEBIAN_FRONTEND=noninteractive

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

FROM kaldi-base AS kaldi-builder

RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi-src

RUN cd /opt/kaldi-src/tools \
    && mkdir -p python \
    && ln -sf $(which python3) python/python3 \
    && ln -sf $(which python3) python/python

RUN cd /opt/kaldi-src/tools \
    && ./extras/install_openblas.sh

RUN cd /opt/kaldi-src/tools \
    && wget -O openfst-1.8.4.tar.gz https://www.openfst.org/twiki/pub/FST/FstDownload/openfst-1.8.4.tar.gz \
    && tar -xzf openfst-1.8.4.tar.gz \
    && cd openfst-1.8.4 \
    && ./configure --enable-shared --enable-far --enable-ngram-fsts --enable-lookahead-fsts --enable-const-fsts --enable-pdt --enable-linear-fsts --prefix=/usr/local \
    && make -j$(nproc) \
    && make install \
    && ldconfig

RUN cd /opt/kaldi-src/src \
    && ./configure --shared --use-cuda=no \
    && make -j$(nproc) depend \
    && cd bin \
    && make -j$(nproc) compute-gop text-to-phonemes

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

# Copier les bibliothèques OpenFST depuis l'étape de construction
COPY --from=kaldi-builder /usr/local/lib/libfst* /usr/local/lib/
COPY --from=kaldi-builder /usr/local/lib/fst /usr/local/lib/fst
COPY --from=kaldi-builder /usr/local/include/fst /usr/local/include/fst

RUN ldconfig

# Copier les binaires Kaldi compilés depuis l'étape précédente
COPY --from=kaldi-builder /opt/kaldi-src/src/bin/compute-gop /usr/local/bin/
COPY --from=kaldi-builder /opt/kaldi-src/src/bin/text-to-phonemes /usr/local/bin/

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
COPY package*.json ./
RUN npm ci

COPY . .

# Changer le propriétaire des fichiers
RUN chown -R node:node /app

USER node

EXPOSE 3000

CMD ["npm", "start"]
