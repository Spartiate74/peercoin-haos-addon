#dockerfile

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

RUN curl -fL \
        "https://github.com/peercoin/peercoin/releases/download/v0.15.1ppc/peercoin-1af7509666a7-aarch64-linux-gnu.tar.gz" \
        -o /tmp/peercoin.tar.gz && \
    tar -xzf /tmp/peercoin.tar.gz \
        --strip-components=1 \
        -C /opt/peercoin && \
    rm -f /tmp/peercoin.tar.gz && \
    chmod 755 /opt/peercoin/peercoind \
              /opt/peercoin/peercoin-cli

COPY run.sh /run.sh

RUN chmod 755 /run.sh

VOLUME ["/data"]

EXPOSE 9901 9902

CMD ["/run.sh"]
