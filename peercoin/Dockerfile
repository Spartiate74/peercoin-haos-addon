FROM debian:bookworm-slim

ARG PPC_VERSION=0.15.1ppc
ARG PPC_ARCHIVE=peercoin-1af7509666a7-aarch64-linux-gnu.tar.gz

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gosu \
        jq \
        nano \
        bash && \
    rm -rf /var/lib/apt/lists/*

RUN useradd \
        --system \
        --home-dir /data \
        --create-home \
        --shell /usr/sbin/nologin \
        peercoin

RUN mkdir -p /tmp/peercoin && \
    echo "Téléchargement de Peercoin Core..." && \
    curl -fL \
      "https://github.com/peercoin/peercoin/releases/download/v${PPC_VERSION}/${PPC_ARCHIVE}" \
      -o /tmp/peercoin.tar.gz && \
    tar -xzf /tmp/peercoin.tar.gz \
      -C /tmp/peercoin && \
    PEERCOIND="$(find /tmp/peercoin -type f -name peercoind -print -quit)" && \
    PEERCOINCLI="$(find /tmp/peercoin -type f -name peercoin-cli -print -quit)" && \
    test -n "${PEERCOIND}" && \
    test -n "${PEERCOINCLI}" && \
    install -m 0755 "${PEERCOIND}" /usr/local/bin/peercoind && \
    install -m 0755 "${PEERCOINCLI}" /usr/local/bin/peercoin-cli && \
    rm -rf /tmp/peercoin /tmp/peercoin.tar.gz

COPY run.sh /opt/peercoin/run.sh

RUN chmod 755 /opt/peercoin/run.sh && \
    mkdir -p /data/peercoin && \
    chown -R peercoin:peercoin /data

VOLUME ["/data"]

EXPOSE 9901

ENTRYPOINT ["/opt/peercoin/run.sh"]
