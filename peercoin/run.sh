#!/bin/sh
set -eu

DATA_DIR="/share/peercoin/data"
CONF_FILE="/share/peercoin/peercoin.conf"
MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"

mkdir -p "$DATA_DIR"
mkdir -p "/share/peercoin/logs"

RPC_USER="${RPC_USER:-ppc_rpc}"
RPC_PASS_FILE="${RPC_PASS_FILE:-/config/peercoin/secrets/rpc_pass}"

if [ ! -r "$RPC_PASS_FILE" ]; then
    echo "ERREUR : fichier du mot de passe RPC introuvable : $RPC_PASS_FILE"
    exit 1
fi

RPC_PASS="$(cat "$RPC_PASS_FILE")"

if [ -z "$RPC_PASS" ]; then
    echo "ERREUR : le mot de passe RPC est vide"
    exit 1
fi

export RPC_USER
export RPC_PASS

export WALLET_NAME="${WALLET_NAME:-android-legacy}"
export WALLET_PASS_FILE="${WALLET_PASS_FILE:-/config/peercoin/secrets/ppc_wallet_pass}"

if [ ! -r "$WALLET_PASS_FILE" ]; then
    echo "ERREUR : fichier du mot de passe introuvable : $WALLET_PASS_FILE"
    exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "Création de $CONF_FILE"

    umask 077

    cat > "$CONF_FILE" <<EOF
server=1
daemon=0
staking=1

rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcport=9902
rpcbind=127.0.0.1
rpcallowip=127.0.0.1

listen=1
port=9901
EOF

    chmod 600 "$CONF_FILE"
else
    echo "$CONF_FILE existe déjà"
    chmod 600 "$CONF_FILE"
fi

echo "Démarrage de peercoind"

/usr/local/bin/peercoind \
    -datadir="$DATA_DIR" \
    -conf="$CONF_FILE" \
    -daemon=0 &

PEERCOIN_PID=$!

cleanup() {
    echo "Arrêt de Peercoin"

    if kill -0 "$PEERCOIN_PID" 2>/dev/null; then
        kill "$PEERCOIN_PID" 2>/dev/null || true
    fi

    if [ -n "${MINTING_PID:-}" ] &&
       kill -0 "$MINTING_PID" 2>/dev/null; then
        kill "$MINTING_PID" 2>/dev/null || true
    fi
}

trap cleanup INT TERM EXIT

echo "Démarrage de la logique de minting"

/bin/sh "$MINTING_SCRIPT" &
MINTING_PID=$!

while :; do
    if ! kill -0 "$PEERCOIN_PID" 2>/dev/null; then
        echo "ERREUR : peercoind s'est arrêté"
        exit 1
    fi

    if ! kill -0 "$MINTING_PID" 2>/dev/null; then
        echo "ERREUR : enable-minting.sh s'est arrêté"
        exit 1
    fi

    sleep 5
done
