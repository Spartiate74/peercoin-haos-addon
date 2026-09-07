#!/bin/sh
set -eu

RPC_USER="${RPC_USER:-ppc_rpc}"
RPC_PASS="${RPC_PASS:?RPC_PASS n'est pas défini}"
RPC_URL="${RPC_URL:-http://127.0.0.1:9902}"
WALLET_NAME="${WALLET_NAME:-android-legacy}"
WALLET_PASS_FILE="${WALLET_PASS_FILE:-/config/peercoin/secrets/ppc_wallet_pass}"
LOG_FILE="${LOG_FILE:-/share/peercoin/minting.log}"

WALLET_URL="$RPC_URL/wallet/$WALLET_NAME"

log() {
    printf '%s - %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" \
        >> "$LOG_FILE"
}

rpc() {
    curl -fsS \
        --user "$RPC_USER:$RPC_PASS" \
        --data-binary "$1" \
        -H 'Content-Type: application/json' \
        "$2"
}

log "Démarrage du script de minting"

if [ ! -r "$WALLET_PASS_FILE" ]; then
    log "ERREUR : fichier du mot de passe introuvable"
    exit 1
fi

log "Attente du RPC Peercoin"

while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"status","method":"getblockchaininfo","params":[]}'
    RESPONSE="$(rpc "$PAYLOAD" "$RPC_URL" 2>/dev/null || true)"

    if printf '%s' "$RESPONSE" |
        jq -e '.result != null' >/dev/null 2>&1; then
        break
    fi

    sleep 10
done

log "RPC disponible"

# Demande le chargement du wallet.
PAYLOAD="$(jq -nc \
    --arg wallet "$WALLET_NAME" \
    '{"jsonrpc":"1.0","id":"load","method":"loadwallet","params":[$wallet,true]}')"

rpc "$PAYLOAD" "$RPC_URL" >> "$LOG_FILE" 2>&1 || true

log "Attente de la synchronisation"

while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"chain","method":"getblockchaininfo","params":[]}'
    INFO="$(rpc "$PAYLOAD" "$RPC_URL")"

    IBD="$(printf '%s' "$INFO" |
        jq -r '.result.initialblockdownload // true')"

    if [ "$IBD" = "false" ]; then
        break
    fi

    log "Blockchain encore en synchronisation"
    sleep 60
done

log "Blockchain synchronisée"

WALLET_PASS="$(cat "$WALLET_PASS_FILE")"

PAYLOAD="$(jq -nc \
    --arg password "$WALLET_PASS" \
    '{"jsonrpc":"1.0","id":"unlock","method":"walletpassphrase","params":[$password,31536000,true]}')"

RESULT="$(rpc "$PAYLOAD" "$WALLET_URL" 2>&1 || true)"

unset WALLET_PASS

if printf '%s' "$RESULT" | jq -e '.error != null' >/dev/null 2>&1; then
    log "ERREUR lors du déverrouillage du wallet"
    exit 1
fi

log "Wallet déverrouillé en mode minting-only"

while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"minting","method":"listminting","params":[100]}'
    RESULT="$(rpc "$PAYLOAD" "$WALLET_URL" 2>/dev/null || true)"

    if [ -n "$RESULT" ]; then
        log "État minting : $RESULT"
    else
        log "Impossible d'interroger listminting"
    fi

    sleep 300
done
