#!/bin/sh
set -eu

DATA_DIR="/share/peercoin/data"
CONF_FILE="/share/peercoin/peercoin.conf"
MINTING_SCRIPT="/opt/peercoin/enable-minting.sh"

mkdir -p "$DATA_DIR"
mkdir -p "/share/peercoin/logs"
mkdir -p "/share/peercoin/secrets"
chown -R peercoin:peercoin /data

: "${RPC_USER:=ppc_rpc}"
: "${RPC_PASS:?RPC_PASS n'est pas défini}"

{
        echo "server=1"
        echo "daemon=0"
        echo "listen=1"
        echo "rpcuser=${RPC_USER}"
        echo "rpcpassword=${RPC_PASS}"
        echo "rpcport=9902"
        echo "port=9901"
        echo "rpcbind=0.0.0.0"
        echo "rpcallowip=172.16.0.0/12"
        echo "rpcallowip=192.168.0.0/16"
        echo "minting=$([ "${MINTING}" = "true" ] && echo 1 || echo 0)"
    } > "${CONF_FILE}"

    chown peercoin:peercoin "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    
export RPC_USER
export RPC_PASS

export WALLET_NAME="android-legacy"
export WALLET_PASS_FILE="/share/peercoin/secrets/ppc_wallet_pass"
export LOG_FILE="/share/peercoin/logs/minting.log"

if [ ! -s "$WALLET_PASS_FILE" ]; then
    echo "ERREUR : fichier du mot de passe du wallet introuvable ou vide : $WALLET_PASS_FILE"
    ls -la /share/peercoin/secrets
    exit 1
fi

chmod 600 "$WALLET_PASS_FILE"

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
