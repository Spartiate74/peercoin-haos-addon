#!/bin/bash

set -Eeuo pipefail

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"
WALLET_NAME="$(jq -r '.walletname // "android-legacy"' "${OPTIONS_FILE}")"
WALLET_PASSPHRASE="$(jq -r '.walletpassphrase // empty' "${OPTIONS_FILE}")"
MINTING="$(jq -r '.minting // true' "${OPTIONS_FILE}")"

if [[ -z "${RPC_PASS}" ]]; then
    echo "Erreur : rpcpassword doit être configuré."
    exit 1
fi

if [[ "${MINTING}" == "true" && -z "${WALLET_PASSPHRASE}" ]]; then
    echo "Erreur : walletpassphrase doit être configuré pour le minting."
    exit 1
fi

mkdir -p "${DATA_DIR}"
chown -R peercoin:peercoin /data

if [[ ! -f "${CONF_FILE}" ]]; then
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
minting=$([[ "${MINTING}" == "true" ]] && echo 1 || echo 0)
EOF

    chown peercoin:peercoin "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
fi

echo "Démarrage de Peercoin Core..."

gosu peercoin peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONF_FILE}" &

PEERCOIND_PID=$!

cleanup() {
    echo "Arrêt de Peercoin Core..."
    kill "${PEERCOIND_PID}" 2>/dev/null || true
    wait "${PEERCOIND_PID}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

cli() {
    gosu peercoin peercoin-cli \
        -datadir="${DATA_DIR}" \
        -conf="${CONF_FILE}" \
        "$@"
}

echo "Attente du démarrage du RPC..."

until cli getblockchaininfo >/dev/null 2>&1; do
    if ! kill -0 "${PEERCOIND_PID}" 2>/dev/null; then
        echo "peercoind s'est arrêté prématurément."
        exit 1
    fi

    sleep 5
done

echo "RPC Peercoin disponible."

echo "Vérification du wallet ${WALLET_NAME}..."

if ! cli listwallets | jq -e --arg wallet "${WALLET_NAME}" \
    'any(.[]; . == $wallet)' >/dev/null; then

    echo "Wallet non chargé."

    if [[ -f "${DATA_DIR}/wallets/${WALLET_NAME}/wallet.dat" || \
          -f "${DATA_DIR}/${WALLET_NAME}/wallet.dat" ]]; then

        echo "Chargement du wallet existant..."
        cli loadwallet "${WALLET_NAME}" || true
    else
        echo "Création du wallet legacy chiffré..."

        cli createwallet \
            "${WALLET_NAME}" \
            false \
            false \
            "${WALLET_PASSPHRASE}" \
            false
    fi
fi

if [[ "${MINTING}" == "true" ]]; then
    echo "Déverrouillage du wallet pour le minting..."

    cli -rpcwallet="${WALLET_NAME}" \
        walletpassphrase \
        "${WALLET_PASSPHRASE}" \
        2147483647 \
        true

    echo "Minting activé."
fi

echo "Peercoin Core fonctionne."

wait "${PEERCOIND_PID}"
