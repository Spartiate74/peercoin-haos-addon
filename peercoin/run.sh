#!/bin/sh

set -eu

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"
WALLET_NAME="$(jq -r '.walletname // "peercoin-mint"' "${OPTIONS_FILE}")"
WALLET_PASSPHRASE="$(jq -r '.walletpassphrase // empty' "${OPTIONS_FILE}")"
MINTING="$(jq -r '.minting // false' "${OPTIONS_FILE}")"

if [ -z "${RPC_PASS}" ]; then
    echo "Erreur : rpcpassword n'est pas configuré."
    exit 1
fi

if [ "${MINTING}" = "true" ] && [ -z "${WALLET_PASSPHRASE}" ]; then
    echo "Erreur : walletpassphrase n'est pas configuré."
    exit 1
fi

mkdir -p "${DATA_DIR}"
chown -R peercoin:peercoin /data

umask 077

if [ ! -f "${CONF_FILE}" ]; then
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

CLI="gosu peercoin peercoin-cli -datadir=${DATA_DIR} -conf=${CONF_FILE}"
CLI_WALLET="${CLI} -rpcwallet=${WALLET_NAME}"

echo "Attente du RPC Peercoin..."

until ${CLI} getblockchaininfo >/dev/null 2>&1; do
    if ! kill -0 "${PEERCOIND_PID}" 2>/dev/null; then
        echo "peercoind s'est arrêté prématurément."
        exit 1
    fi

    sleep 5
done

echo "RPC Peercoin disponible."

echo "Vérification du wallet ${WALLET_NAME}..."

if ! ${CLI} listwallets | jq -e --arg wallet "${WALLET_NAME}" \
    'index($wallet) != null' >/dev/null 2>&1; then

    echo "Wallet non chargé."

    if ! ${CLI} loadwallet "${WALLET_NAME}" >/dev/null 2>&1; then
        echo "Création du wallet legacy ${WALLET_NAME}..."

        ${CLI} createwallet \
            "${WALLET_NAME}" \
            false \
            false \
            "${WALLET_PASSPHRASE}" \
            false
    fi
fi

echo "Wallet ${WALLET_NAME} disponible."

if [ "${MINTING}" = "true" ]; then
    echo "Déverrouillage du wallet pour le minting..."

    if ${CLI_WALLET} walletpassphrase \
        "${WALLET_PASSPHRASE}" \
        2147483647 \
        true; then

        echo "Minting activé."
    else
        echo "Erreur : impossible de déverrouiller le wallet."
        exit 1
    fi
else
    echo "Minting désactivé."
fi

wait "${PEERCOIND_PID}"
