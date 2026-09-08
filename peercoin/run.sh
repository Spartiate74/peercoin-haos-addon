#!/bin/sh
set -eu

DATA_DIR="/share/peercoin/data"
CONF_FILE="/share/peercoin/peercoin.conf"
MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"
OPTIONS_FILE="/data/options.json"

mkdir -p "$DATA_DIR"
mkdir -p "/share/peercoin/logs"
mkdir -p "/config/peercoin/secrets"

if [ ! -r "$OPTIONS_FILE" ]; then
    echo "ERREUR : fichier $OPTIONS_FILE introuvable"
    exit 1
fi
RPC_USER="$(jq -r '.rpcuser // "ppc_rpc"' "$OPTIONS_FILE")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "$OPTIONS_FILE")"
MINTING="$(jq -r '.minting // false' "$OPTIONS_FILE")"
if [ -z "$RPC_PASS" ]; then
    echo "ERREUR : rpcpassword est vide"
    exit 1
fi
export RPC_USER
export RPC_PASS

export WALLET_NAME="android-legacy"
export WALLET_PASS_FILE="/config/peercoin/secrets/ppc_wallet_pass"
export LOG_FILE="/share/peercoin/logs/minting.log"

if [ ! -r "$WALLET_PASS_FILE" ]; then
    echo "ERREUR : fichier du mot de passe du wallet introuvable : $WALLET_PASS_FILE"
    exit 1
fi

# Important :
# peercoind doit rester au premier plan dans le conteneur.
# L'option -daemon=0 est utilisée par les versions compatibles Bitcoin Core.
peercoind \
    -datadir="$DATA_DIR" \
    -conf="$CONF_FILE" \
    -daemon=0 &
PEERCOIN_PID=$!

cleanup() {
    echo "Arrêt de Peercoin..."

    kill "$PEERCOIN_PID" 2>/dev/null || true

    if [ -n "${MINTING_PID:-}" ]; then
        kill "$MINTING_PID" 2>/dev/null || true
    fi
}

trap cleanup INT TERM EXIT

# Le script attend lui-même que le RPC soit disponible,
# que le wallet soit chargé et que la blockchain soit synchronisée.
MINTING_PID=""

if [ "$MINTING" = "true" ]; then
    echo "Minting activé"
    /bin/sh "$MINTING_SCRIPT" &
    MINTING_PID=$!
else
    echo "Minting désactivé"
    MINTING_PID=""
fi


# Surveille les deux processus.
while :; do
    if ! kill -0 "$PEERCOIN_PID" 2>/dev/null; then
        echo "ERREUR : peercoind s'est arrêté"
        wait "$PEERCOIN_PID" 2>/dev/null || true
        exit 1
    fi

    if [ -n "${MINTING_PID:-}" ] &&
       ! kill -0 "$MINTING_PID" 2>/dev/null; then
        echo "ERREUR : le script de minting s'est arrêté"
        wait "$MINTING_PID" 2>/dev/null || true
        exit 1
    fi

    sleep 5
done
