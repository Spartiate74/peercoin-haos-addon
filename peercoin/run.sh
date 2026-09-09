#!/bin/sh
set -eu

DATA_DIR="/share/peercoin/data"
CONF_FILE="/share/peercoin/peercoin.conf"
MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"
OPTIONS_FILE="/data/options.json"

mkdir -p "$DATA_DIR"
mkdir -p "/share/peercoin/logs"
mkdir -p "/config/peercoin/secrets"
chown -R peercoin:peercoin /data

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

#Creation peercoin.conf
cat > "$CONF_FILE" <<EOF
server=1
daemon=0

listen=1
port=9901

rpcuser=${RPC_USER}
rpcpassword=${RPC_PASS}

rpcbind=0.0.0.0:9902
rpcallowip=192.168.184.0/24

maxconnections=32
EOF

chown peercoin:peercoin "${CONF_FILE}"
chmod 600 "$CONF_FILE"

if [ ! -r "$WALLET_PASS_FILE" ]; then
    echo "ERREUR : fichier du mot de passe du wallet introuvable : $WALLET_PASS_FILE"

    echo "Diagnostic des montages :"

    ls -ld /config 2>/dev/null || true
    ls -ld /config/peercoin 2>/dev/null || true
    ls -ld /config/peercoin/secrets 2>/dev/null || true
    ls -l /config/peercoin/secrets 2>/dev/null || true

    exit 1
fi



# Important :
# peercoind doit rester au premier plan dans le conteneur.
# L'option -daemon=0 est utilisée par les versions compatibles Bitcoin Core.

cleanup() {
    echo "Arrêt de Peercoin..."

    kill "$PEERCOIN_PID" 2>/dev/null || true

    if [ -n "${MINTING_PID:-}" ]; then
        kill "$MINTING_PID" 2>/dev/null || true
    fi
}

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
