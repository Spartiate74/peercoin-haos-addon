#!/bin/sh
set -eu

DATA_DIR="/share/peercoin/data"
CONF_FILE="/share/peercoin/peercoin.conf"
MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"

mkdir -p "$DATA_DIR"
mkdir -p "/share/peercoin/logs"

# Vérifications de configuration
: "${RPC_USER:=ppc_rpc}"
: "${RPC_PASS:?RPC_PASS n'est pas défini}"

export RPC_USER
export RPC_PASS

# Le fichier doit être fourni par le mapping Home Assistant
export WALLET_PASS_FILE="${WALLET_PASS_FILE:-/config/peercoin/secrets/ppc_wallet_pass}"

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
    kill "$MINTING_PID" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

# Le script attend lui-même que le RPC soit disponible,
# que le wallet soit chargé et que la blockchain soit synchronisée.
/bin/sh "$MINTING_SCRIPT" &
MINTING_PID=$!

# Surveille les deux processus.
while :; do
    if ! kill -0 "$PEERCOIN_PID" 2>/dev/null; then
        echo "ERREUR : peercoind s'est arrêté"
        wait "$PEERCOIN_PID" 2>/dev/null || true
        exit 1
    fi

    if ! kill -0 "$MINTING_PID" 2>/dev/null; then
        echo "ERREUR : le script de minting s'est arrêté"
        wait "$MINTING_PID" 2>/dev/null || true
        exit 1
    fi

    sleep 5
done
