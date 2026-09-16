#!/bin/sh

set -eu

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"
WALLET_NAME="$(jq -r '.walletname // "android-legacy"' "${OPTIONS_FILE}")"
WALLET_PASSPHRASE="$(jq -r '.walletpassphrase // empty' "${OPTIONS_FILE}")"
MINTING="$(jq -r '.minting // false' "${OPTIONS_FILE}")"

if [ -z "${RPC_PASS}" ]; then
    echo "Erreur : rpcpassword n'est pas configuré."
    exit 1
fi

mkdir -p "${DATA_DIR}"
chown -R peercoin:peercoin /data

if [ ! -f "${CONF_FILE}" ]; then
    umask 077

    cat > "${CONF_FILE}" <<EOF
server=1
daemon=0
listen=1
port=9901
rpcport=9902
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASS}
minting=0
EOF

    chown peercoin:peercoin "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
fi

echo "Démarrage de Peercoin Core..."

gosu peercoin peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONF_FILE}" &

PEERCOIND_PID="$!"

cleanup() {
    echo "Arrêt de Peercoin Core..."
    kill "${PEERCOIND_PID}" 2>/dev/null || true
    wait "${PEERCOIND_PID}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

echo "RPC Peercoin disponible."

wait "${PEERCOIND_PID}"
