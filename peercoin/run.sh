#!/bin/sh

set -eu

DATA_DIR="/data/peercoin"
CONF_FILE="${DATA_DIR}/peercoin.conf"
OPTIONS_FILE="/data/options.json"

echo "=== Peercoin : démarrage ==="
echo "Options :"
cat "${OPTIONS_FILE}"

RPC_USER="$(jq -r '.rpcuser // empty' "${OPTIONS_FILE}")"
RPC_PASS="$(jq -r '.rpcpassword // empty' "${OPTIONS_FILE}")"

if [ -z "${RPC_PASS}" ]; then
    echo "ERREUR : rpcpassword est vide."
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
EOF

    chown peercoin:peercoin "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
fi

echo "=== Lancement de peercoind ==="

exec gosu peercoin peercoind \
    -datadir="${DATA_DIR}" \
    -conf="${CONF_FILE}"
