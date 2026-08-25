#!/bin/sh
# test_agent_runtime.sh - testes comportamentais OFFLINE.
# Nao faz login e nao acessa a internet/jogo.

set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
BASE_TMP=${TMPDIR:-/tmp}
WORK="$BASE_TMP/furia-v21-test-$$"
mkdir -p "$WORK" || exit 1
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '[OK]   %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$*"; }

printf '=== V2.1 - testes offline de comportamento ===\n'

# ------------------------------------------------------------
# state.sh: slot deduplicado e lock velho expira.
# ------------------------------------------------------------
TMP="$WORK/state"
mkdir -p "$TMP"
export TMP
. "$ROOT/state.sh"

if event_slot_seen "slot-a"; then
    fail 'slot inexistente foi tratado como visto'
else
    ok 'slot inexistente nao bloqueia evento'
fi

event_slot_mark "slot-a"
if event_slot_seen "slot-a"; then
    ok 'slot marcado impede repeticao'
else
    fail 'slot marcado nao foi reconhecido'
fi

cat > "$TMP/event_lock" <<EOF
status=running
pid=$$
started=1
updated=1
EOF
EVENT_LOCK_TTL=1
export EVENT_LOCK_TTL
if event_lock_active; then
    fail 'event_lock antigo permaneceu ativo'
else
    ok 'event_lock antigo expira por TTL'
fi
unset EVENT_LOCK_TTL

# ------------------------------------------------------------
# resource_guard: gasto perigoso deve ser negado.
# ------------------------------------------------------------
TMP="$WORK/resource"
mkdir -p "$TMP"
export TMP
. "$ROOT/resource_guard.sh"
if resource_allow gold 10 blessing >/dev/null 2>&1; then
    fail 'resource_guard permitiu blessing'
else
    ok 'resource_guard nega blessing'
fi
if resource_allow gold 1 cave_gold_boost >/dev/null 2>&1; then
    fail 'resource_guard permitiu boost de ouro da caverna'
else
    ok 'resource_guard nega boost de ouro da caverna'
fi

# ------------------------------------------------------------
# check.sh: apply_event vazio nao pode chamar rede; evento valido usa 1 link.
# ------------------------------------------------------------
TMP="$WORK/check"
mkdir -p "$TMP"
export TMP
FUNC_use_elixir=y
FUNC_check_rewards=y
FUNC_collect_mission_rewards=y
COLLECT_REWARDS_RUNTIME=y
CALLS="$TMP/calls"
: > "$CALLS"

fetch_page() {
    _tf_path="$1"
    printf '%s\n' "$_tf_path" >> "$CALLS"
    case "$_tf_path" in
        /demo/)
            printf "%s\n" "/demo/enterFight/?r=111" "/demo/enterFight/?r=222" > "$TMP/SRC"
            ;;
        /demo/enterFight/*)
            printf "logged\n" > "$TMP/SRC"
            ;;
        /inv/chest/)
            printf "/inv/chest/use/10/1/?r=1\n" > "$TMP/SRC"
            ELIXIR_STEP=0
            ;;
        /inv/chest/use/*)
            ELIXIR_STEP=$((ELIXIR_STEP + 1))
            case "$ELIXIR_STEP" in
                1) printf "/inv/chest/use/11/1/?r=2\n" > "$TMP/SRC" ;;
                2) printf "/inv/chest/use/12/1/?r=3\n" > "$TMP/SRC" ;;
                *) : > "$TMP/SRC" ;;
            esac
            ;;
        *) : > "$TMP/SRC" ;;
    esac
    unset _tf_path
    return 0
}

. "$ROOT/check.sh"

: > "$CALLS"
if apply_event "" >/dev/null 2>&1; then
    fail 'apply_event vazio retornou sucesso'
elif [ -s "$CALLS" ]; then
    fail 'apply_event vazio tentou requisicao'
else
    ok 'apply_event vazio falha sem requisicao fantasma'
fi

: > "$CALLS"
if apply_event demo >/dev/null 2>&1; then
    _n=`wc -l < "$CALLS" | tr -d ' '`
    if [ "$_n" -eq 2 ] && grep -q '^/demo/enterFight/?r=111$' "$CALLS"; then
        ok 'apply_event usa somente o primeiro link valido'
    else
        fail 'apply_event enviou quantidade/link inesperado'
    fi
else
    fail 'apply_event valido falhou no fixture offline'
fi

: > "$CALLS"
ELIXIR_STEP=0
if use_elixir >/dev/null 2>&1; then
    _uses=`grep -c '^/inv/chest/use/' "$CALLS" 2>/dev/null || true`
    if [ "$_uses" -eq 3 ]; then
        ok 'use_elixir processa a lista mutavel sem pular itens'
    else
        fail "use_elixir enviou $_uses usos; esperado 3"
    fi
else
    fail 'use_elixir falhou no fixture offline'
fi

# ------------------------------------------------------------
# action_runner: mesma acao eterna deve abortar, nao fingir progresso.
# ------------------------------------------------------------
TMP="$WORK/runner"
mkdir -p "$TMP"
export TMP
RUN_CALLS=0
fetch_page() {
    RUN_CALLS=$((RUN_CALLS + 1))
    printf '/campaign/attack/?r=999\n' > "${2:-$TMP/SRC}"
    return 0
}
priority_guard() { return 0; }
is_logged_in() { return 0; }
. "$ROOT/action_runner.sh"

if activity_run_links "/campaign/" '/campaign/attack/[?]r=[0-9]+' 30 fixture >/dev/null 2>&1; then
    fail 'action_runner aceitou acao eterna como progresso'
else
    if [ "${ACTIVITY_RUN_COUNT:-0}" -le 3 ]; then
        ok 'action_runner aborta repeticao sem progresso'
    else
        fail 'action_runner demorou demais para abortar repeticao'
    fi
fi

printf '\nResultado runtime: %s OK | %s FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
