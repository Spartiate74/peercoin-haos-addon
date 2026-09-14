#!/bin/sh
set -eu pipefail

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
#MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"

mkdir -p "$DATA_DIR"
chown -R peercoin:peercoin /data

#mkdir -p "/share/peercoin/logs"
if [ ! -f "${CONF_FILE}" ]; then

    RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' /data/options.json)"
    RPC_PASSWORD="$(jq -r '.rpcpassword // empty' /data/options.json)"
    MINTING="$(jq -r '.minting // false' /data/options.json)"

    if [ -z "${RPC_PASSWORD}" ]; then
        echo "Erreur : le mot de passe RPC n'est pas configuré."
        exit 1
    fi
         umask 077

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
        echo "rpcallowip=127.0.0.1/24"
        echo #"wallet=android-legacy"
        echo "minting=$([ "${MINTING}" = "true" ] && echo 1 || echo 0)"
    } > "${CONF_FILE}"

    chown peercoin:peercoin "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
fi

exec gosu peercoin peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONF_FILE}"
    
