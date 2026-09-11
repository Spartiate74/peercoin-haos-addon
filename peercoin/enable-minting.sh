#!/bin/sh
set -eu

RPC_USER="${RPC_USER:-ppc_rpc}"
RPC_PASS="${RPC_PASS:?RPC_PASS n'est pas défini}"
RPC_URL="${RPC_URL:-http://127.0.0.1:9902}"
WALLET_NAME="${WALLET_NAME:-android-legacy}"
WALLET_PASS_FILE="${WALLET_PASS_FILE:-/config/peercoin/secrets/ppc_wallet_pass}"
LOG_FILE="${LOG_FILE:-/share/peercoin/logs/minting.log}"

WALLET_URL="$RPC_URL/wallet/$WALLET_NAME"

log() {
    MESSAGE="$*"
    printf '%s - %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$MESSAGE" | tee -a "$LOG_FILE"
}

rpc() {
    PAYLOAD="$1"
    URL="$2"

    curl -fsS \
        --user "$RPC_USER:$RPC_PASS" \
        --data-binary "$PAYLOAD" \
        -H 'Content-Type: application/json' \
        "$URL"
}

if [ ! -r "$WALLET_PASS_FILE" ]; then
    log "ERREUR : fichier du mot de passe absent"
    exit 1
fi

log "Attente de la disponibilité complète du RPC Peercoin"

while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"rpc","method":"getblockchaininfo","params":[]}'

    RESPONSE="$(rpc "$PAYLOAD" "$RPC_URL" 2>/dev/null || true)"

    if printf '%s' "$RESPONSE" |
        jq -e '.result != null and .error == null' >/dev/null 2>&1; then
        log "RPC Peercoin disponible"
        break
    fi

    log "RPC encore en initialisation"
    sleep 15
done

log "RPC disponible"

# Charge le wallet au démarrage.
# Si le wallet est déjà chargé, l'erreur est ignorée.
PAYLOAD="$(jq -nc \
    --arg wallet "$WALLET_NAME" \
    '{
        jsonrpc: "1.0",
        id: "loadwallet",
        method: "loadwallet",
        params: [$wallet, true]
    }')"

LOAD_RESULT="$(rpc "$PAYLOAD" "$RPC_URL" 2>&1 || true)"

if printf '%s' "$LOAD_RESULT" |
    jq -e '.error != null' >/dev/null 2>&1; then
    log "Wallet déjà chargé ou réponse de chargement non standard"
else
    log "Wallet chargé automatiquement"
fi

# Vérifie que le wallet apparaît bien dans listwallets.
while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"wallets","method":"listwallets","params":[]}'
    WALLETS="$(rpc "$PAYLOAD" "$RPC_URL" 2>/dev/null || true)"

    if printf '%s' "$WALLETS" |
        jq -e --arg wallet "$WALLET_NAME" \
        '.result | index($wallet) != null' >/dev/null 2>&1; then
        break
    fi

    log "Wallet encore indisponible"
    sleep 10
done

log "Wallet $WALLET_NAME disponible"

log "Attente de la synchronisation complète de la blockchain"

while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"chain","method":"getblockchaininfo","params":[]}'

    INFO="$(rpc "$PAYLOAD" "$RPC_URL" 2>/dev/null || true)"

    if [ -z "$INFO" ]; then
        log "RPC temporairement indisponible pendant le chargement de la blockchain"
        sleep 15
        continue
    fi

    RPC_ERROR="$(printf '%s' "$INFO" | jq -r '.error.message // empty' 2>/dev/null || true)"

    if [ -n "$RPC_ERROR" ]; then
        log "Blockchain encore en initialisation : $RPC_ERROR"
        sleep 15
        continue
    fi

    IBD="$(printf '%s' "$INFO" |
        jq -r '.result.initialblockdownload // true' 2>/dev/null || echo true)"

    if [ "$IBD" = "false" ]; then
        break
    fi

    PROGRESS="$(printf '%s' "$INFO" |
        jq -r '.result.verificationprogress // 0' 2>/dev/null || echo 0)"

    log "Blockchain encore en synchronisation : progression $PROGRESS"
    sleep 60
done

log "Blockchain synchronisée"


# Déverrouille le portefeuille en mode minting-only.
WALLET_PASS="$(cat "$WALLET_PASS_FILE")"

PAYLOAD="$(jq -nc \
    --arg password "$WALLET_PASS" \
    '{
        jsonrpc: "1.0",
        id: "unlock",
        method: "walletpassphrase",
        params: [$password, 31536000, true]
    }')"

UNLOCK_RESULT="$(rpc "$PAYLOAD" "$WALLET_URL" 2>&1 || true)"

unset WALLET_PASS

if printf '%s' "$UNLOCK_RESULT" |
    jq -e '.error != null' >/dev/null 2>&1; then
    log "ERREUR : impossible de déverrouiller le wallet"
    exit 1
fi

log "Wallet déverrouillé en mode minting-only"

# Surveillance permanente du minting.
while :; do
    PAYLOAD='{"jsonrpc":"1.0","id":"minting","method":"listminting","params":[100]}'
    MINTING="$(rpc "$PAYLOAD" "$WALLET_URL" 2>/dev/null || true)"

    if [ -n "$MINTING" ]; then
        MATURE="$(printf '%s' "$MINTING" |
            jq '[.result[]? | select(.status == "mature")] | length' \
            2>/dev/null || echo 0)"

        IMMATURE="$(printf '%s' "$MINTING" |
            jq '[.result[]? | select(.status == "immature")] | length' \
            2>/dev/null || echo 0)"

        log "Sorties matures : $MATURE ; immatures : $IMMATURE"
    else
        log "Impossible d'interroger listminting"
    fi

    sleep 300
done
