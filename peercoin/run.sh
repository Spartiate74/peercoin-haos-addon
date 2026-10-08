#!/bin/sh

set -eu

DATADIR="/data/peercoin"
CONF="${DATADIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"
WALLET="$(jq -r '.walletname // "android-legacy"' "${OPTIONS_FILE}")"
WALLET_PASSPHRASE="$(jq -r '.walletpassphrase // empty' "${OPTIONS_FILE}")"
MINTING="$(jq -r '.minting // false' "${OPTIONS_FILE}")"

if [ -z "${RPC_PASS}" ]; then
    echo "Erreur : rpcpassword n'est pas configuré."
    exit 1
fi

mkdir -p "${DATADIR}"
chown -R peercoin:peercoin /data

if [ ! -f "${CONF}" ]; then
    umask 077

    cat > "${CONF}" <<EOF
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
wallet=android-legacy
maxconnections=50
EOF

    chown peercoin:peercoin "${CONF}"
    chmod 600 "${CONF}"
fi

echo "Vérification du wallet ${WALLET}..."

if ! gosu peercoin peercoin-cli \
    -datadir="${DATADIR}" \
    -conf="${CONF}" \
    listwallets | jq -e --arg wallet "${WALLETNAME}" \
    'index($wallet) != null' >/dev/null; then

    echo "Wallet non chargé, tentative de chargement..."

    if ! gosu peercoin peercoin-cli \
        -datadir="${DATADIR}" \
        -conf="${CONF}" \
        loadwallet "${WALLET}"; then

        echo "Le wallet n'existe pas. Création du wallet legacy..."

        gosu peercoin peercoin-cli \
            -datadir="${DATADIR}" \
            -conf="${CONF}" \
            createwallet "${WALLET}" false false "" false
    fi
fi

if [ "${MINTING}" = "true" ]; then
    echo "Déverrouillage du wallet pour le minting..."

    gosu peercoin peercoin-cli \
        -datadir="${DATADIR}" \
        -conf="${CONF}" \
        -rpcwallet="${WALLET}" \
        walletpassphrase "${WALLET_PASSPHRASE}" 2147483647 true

    echo "Minting activé."
fi

echo "Démarrage de Peercoin Core..."

gosu peercoin peercoind \
    -DATADIR="${DATADIR}" \
    -CONF="${CONF}" \
    -WALLET="$(WALLET)" &

PEERCOIND_PID="$!"

cleanup() {
    echo "Arrêt de Peercoin Core..."
    kill "${PEERCOIND_PID}" 2>/dev/null || true
    wait "${PEERCOIND_PID}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

echo "RPC Peercoin disponible."

wait "${PEERCOIND_PID}"
