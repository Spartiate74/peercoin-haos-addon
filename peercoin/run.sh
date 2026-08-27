#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/data/peercoin"
CONFIG_FILE="${DATA_DIR}/peercoin.conf"

mkdir -p "${DATA_DIR}"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' /data/options.json)"
RPC_PASSWORD="$(jq -r '.rpcpassword // empty' /data/options.json)"
MINTING="$(jq -r '.minting // false' /data/options.json)"

if [ -z "${RPC_PASSWORD}" ]; then
    echo "Erreur : le mot de passe RPC n'est pas configuré."
    exit 1
fi

if [ ! -f "${CONFIG_FILE}" ]; then
    {
        echo "server=1"
        echo "daemon=0"
        echo "listen=1"
        echo "port=9901"
        echo "rpcport=9902"
        echo "rpcuser=${RPC_USER}"
        echo "rpcpassword=${RPC_PASSWORD}"
        echo "rpcbind=0.0.0.0"
        echo "rpcallowip=172.16.0.0/12"
        echo "rpcallowip=192.168.0.0/16"

        if [ "${MINTING}" = "true" ]; then
            echo "minting=1"
        else
            echo "minting=0"
        fi
    } > "${CONFIG_FILE}"

    chmod 600 "${CONFIG_FILE}"
fi

chown -R peercoin:peercoin "${DATA_DIR}"

exec gosu peercoin /opt/peercoin/peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONFIG_FILE}"
