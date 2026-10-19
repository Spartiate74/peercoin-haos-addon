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

umask 077
cat > "${CONF}" <<EOF
server=1
daemon=0
listen=1
port=9901
rpcport=9902
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=172.30.32.0/23
rpcuser=${RPC_USER}
rpcpassword=${RPC_PASS}
wallet=${WALLET}
maxconnections=50
dbcache=450
EOF

if [ "${MINTING}" = "true" ]; then
    echo "Minting activé dans la config."
else
    echo "Minting désactivé dans la config."
fi

chown peercoin:peercoin "${CONF}"
chmod 600 "${CONF}"

echo "Démarrage de Peercoin Core..."

gosu peercoin peercoind \
    -datadir="${DATADIR}" \
    -conf="${CONF}" &
PEERCOIND_PID="$!"

cleanup() {
    echo "Arrêt de Peercoin Core..."
    kill "${PEERCOIND_PID}" 2>/dev/null || true
    wait "${PEERCOIND_PID}" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

echo "Attente du démarrage RPC..."

until gosu peercoin peercoin-cli \
    -datadir="${DATADIR}" \
    -conf="${CONF}" \
    getblockchaininfo >/dev/null 2>&1; do
    sleep 2
done

echo "Vérification du wallet ${WALLET}..."

if ! gosu peercoin peercoin-cli \
    -datadir="${DATADIR}" \
    -conf="${CONF}" \
    listwallets | jq -e --arg wallet "${WALLET}" 'index($wallet) != null' >/dev/null; then

    echo "Wallet non chargé, tentative de chargement..."

    if ! gosu peercoin peercoin-cli \
        -datadir="${DATADIR}" \
        -conf="${CONF}" \
        loadwallet "${WALLET}"; then

        echo "Le wallet n'existe pas. Création du wallet legacy..."
        gosu peercoin peercoin-cli \
            -datadir="${DATADIR}" \
            -conf="${CONF}" \
            createwallet "${WALLET}" false false "" false false
    fi
fi

if [ "${MINTING}" = "true" ] && [ -n "${WALLET_PASSPHRASE}" ]; then
    echo "Déverrouillage du wallet pour le minting..."
    gosu peercoin peercoin-cli \
        -datadir="${DATADIR}" \
        -conf="${CONF}" \
        -rpcwallet="${WALLET}" \
        walletpassphrase "${WALLET_PASSPHRASE}" 2147483647 true
    echo "Minting activé."
fi

wait "${PEERCOIND_PID}"
