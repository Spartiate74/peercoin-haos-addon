FROM debian:bookworm-slim

ARG PPC_VERSION=0.15.1ppc
ARG PPC_ARCHIVE=peercoin-1af7509666a7-aarch64-linux-gnu.tar.gz

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        bash \
        gosu \
        jq && \
    rm -rf /var/lib/apt/lists/*

RUN useradd \
        --system \
        --home-dir /data \
        --create-home \
        --shell /usr/sbin/nologin \
        peercoin

WORKDIR /opt/peercoin

RUN mkdir -p /tmp/peercoin && \
    curl -fL \
        "https://github.com/peercoin/peercoin/releases/download/v${PPC_VERSION}/${PPC_ARCHIVE}" \
        -o /tmp/peercoin.tar.gz && \
    tar -xzf /tmp/peercoin.tar.gz \
        -C /tmp/peercoin && \
    PEERCOIND="$(find /tmp/peercoin -type f -name peercoind -print -quit)" && \
    PEERCOINCLI="$(find /tmp/peercoin -type f -name peercoin-cli -print -quit)" && \
    test -n "$PEERCOIND" && \
    test -n "$PEERCOINCLI" && \
    install -m 0755 "$PEERCOIND" /usr/local/bin/peercoind && \
    install -m 0755 "$PEERCOINCLI" /usr/local/bin/peercoin-cli && \
    rm -rf /tmp/peercoin /tmp/peercoin.tar.gz

COPY run.sh /opt/peercoin/run.sh
COPY enable-minting.sh /opt/peercoin/enable-minting.sh

RUN chmod 700 /opt/peercoin/run.sh && \
    chmod 700 /opt/peercoin/enable-minting.sh

VOLUME ["/share"]

EXPOSE 9901 9902

ENTRYPOINT ["/opt/peercoin/run.sh"]
