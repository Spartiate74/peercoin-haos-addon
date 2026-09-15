#!/bin/sh

set -eu

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"
WALLET_NAME="$(jq -r '.walletname // "android-legacy"' "${OPTIONS_FILE}")"
WALLET_PASSPHRASE="$(jq -r '.walletpassphrase // empty' "${OPTIONS_FILE}")"
MINTING="$(jq -r '.minting // true' "${OPTIONS_FILE}")"

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
minting=$([ "${MINTING}" = "true" ] && echo 1 || echo 0)
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

RPC_CLI="peercoin-cli -datadir=${DATA_DIR} -conf=${CONF_FILE} -rpcwallet=${WALLET_NAME}"

echo "Attente du démarrage du RPC..."

until gosu peercoin ${RPC_CLI} getblockchaininfo >/dev/null 2>&1; do
    if ! kill -0 "${PEERCOIND_PID}" 2>/dev/null; then
        echo "peercoind s'est arrêté prématurément."
        exit 1
    fi

    sleep 5
done

echo "RPC Peercoin disponible."

echo "Vérification du wallet ${WALLET_NAME}..."

if ! gosu peercoin peercoin-cli \
    -datadir="${DATA_DIR}" \
    -conf="${CONF_FILE}" \
    listwallets | jq -e --arg wallet "${WALLET_NAME}" \
    'index($wallet) != null' >/dev/null; then

    echo "Wallet non chargé, tentative de chargement..."

    if ! gosu peercoin peercoin-cli \
        -datadir="${DATA_DIR}" \
        -conf="${CONF_FILE}" \
        loadwallet "${WALLET_NAME}"; then

        echo "Le wallet n'existe pas. Création du wallet legacy..."

        gosu peercoin peercoin-cli \
            -datadir="${DATA_DIR}" \
            -conf="${CONF_FILE}" \
            createwallet "${WALLET_NAME}" false false "" false
    fi
fi

#if [ "${MINTING}" = "true" ]; then
    #echo "Déverrouillage du wallet pour le minting..."

    #if ! gosu peercoin ${RPC_CLI} \
        walletpassphrase "${WALLET_PASSPHRASE}" 2147483647 true; then
        echo "Erreur : impossible de déverrouiller le wallet pour le minting."
        echo "Vérifiez la passphrase et assurez-vous que le wallet est chiffré."
        exit 1
    #fi

    #echo "Minting activé."
#fi

wait "${PEERCOIND_PID}"
