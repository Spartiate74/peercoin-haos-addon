#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/data/peercoin"
CONFIG_FILE="${DATA_DIR}/peercoin.conf"

mkdir -p "${DATA_DIR}"
chown -R peercoin:peercoin /data

if [ ! -f "${CONFIG_FILE}" ]; then
    RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' /data/options.json)"
    RPC_PASSWORD="$(jq -r '.rpcpassword // empty' /data/options.json)"
    MINTING="$(jq -r '.minting // false' /data/options.json)"

    if [ -z "${RPC_PASSWORD}" ]; then
        echo "Erreur : le mot de passe RPC n'est pas configuré."
        exit 1
    fi

    {
        echo "server=1"
        echo "daemon=0"
        echo "listen=1"
        echo "rpcuser=${RPC_USER}"
        echo "rpcpassword=${RPC_PASSWORD}"
        echo "rpcport=9902"
        echo "port=9901"
        echo "rpcbind=0.0.0.0"
        echo "rpcallowip=172.16.0.0/12"
        echo "rpcallowip=192.168.184.0/24"
        echo "minting=$([ "${MINTING}" = "true" ] && echo 1 || echo 0)"
    } > "${CONFIG_FILE}"

    chown peercoin:peercoin "${CONFIG_FILE}"
    chmod 600 "${CONFIG_FILE}"
fi

exec gosu peercoin peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONFIG_FILE}"
