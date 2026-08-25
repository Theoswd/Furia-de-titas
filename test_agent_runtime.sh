#!/bin/sh
# test_agent_runtime.sh - testes comportamentais OFFLINE.
# Nao faz login e nao acessa a internet/jogo.

set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
BASE_TMP=${TMPDIR:-/tmp}
WORK="$BASE_TMP/furia-v212-test-$$"
mkdir -p "$WORK" || exit 1
trap 'rm -rf "$WORK"' 0 HUP INT TERM

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '[OK]   %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$*"; }

printf '=== V2.1.2 - testes offline de comportamento ===\n'

TMP="$WORK/state"
mkdir -p "$TMP"
export TMP
. "$ROOT/state.sh"

if event_slot_seen "slot-a"; then fail 'slot inexistente foi tratado como visto'; else ok 'slot inexistente nao bloqueia evento'; fi
event_slot_mark "slot-a"
if event_slot_seen "slot-a"; then ok 'slot marcado impede repeticao'; else fail 'slot marcado nao foi reconhecido'; fi

cat > "$TMP/event_lock" <<EOF
status=running
pid=$$
started=1
updated=1
EOF
EVENT_LOCK_TTL=1
export EVENT_LOCK_TTL
if event_lock_active; then fail 'event_lock antigo permaneceu ativo'; else ok 'event_lock antigo expira por TTL'; fi
unset EVENT_LOCK_TTL

rm -f "$TMP/event_retry"
if event_retry_allowed "slot-b"; then ok 'primeira tentativa de evento e permitida'; else fail 'primeira tentativa de evento foi bloqueada'; fi
event_retry_mark "slot-b"
if event_retry_allowed "slot-b"; then fail 'retry imediato de evento nao entrou em cooldown'; else ok 'retry imediato de evento entra em cooldown'; fi
cat > "$TMP/event_retry" <<EOF
slot-b|1|3
EOF
if event_retry_allowed "slot-b"; then fail 'quarta tentativa de evento foi permitida'; else ok 'evento limita retries a tres tentativas'; fi

TMP="$WORK/resource"
mkdir -p "$TMP"
export TMP
. "$ROOT/resource_guard.sh"
if resource_allow gold 10 blessing >/dev/null 2>&1; then fail 'resource_guard permitiu blessing'; else ok 'resource_guard nega blessing'; fi
if resource_allow gold 1 cave_gold_boost >/dev/null 2>&1; then fail 'resource_guard permitiu boost de ouro da caverna'; else ok 'resource_guard nega boost de ouro da caverna'; fi

TMP="$WORK/blessing"
mkdir -p "$TMP"
export TMP
URL="https://furiadetitas.net"
export URL
HTTP_CALLED=0
_rc_run() { HTTP_CALLED=$((HTTP_CALLED + 1)); return 0; }
. "$ROOT/blessing.sh"
if run_curl "${URL}/effshop/blessing/?r=123" >/dev/null 2>&1; then
    fail 'endpoint da Bencao retornou sucesso'
elif [ "$HTTP_CALLED" -ne 0 ]; then
    fail 'endpoint da Bencao chegou ao motor HTTP'
else
    ok 'Bencao bloqueada antes do curl'
fi
if use_blessing >/dev/null 2>&1; then fail 'use_blessing ainda retorna sucesso'; else ok 'use_blessing permanece desativada'; fi

TMP="$WORK/clan"
mkdir -p "$TMP"
export TMP
CLD=99
FUNC_clan_missions=y
export CLD FUNC_clan_missions
CLAN_MODE=quest
DUN_ATTACKS=0
CLAN_CALLS="$TMP/calls"
: > "$CLAN_CALLS"
sleep() { :; }
is_logged_in() { return 0; }
fetch_page() {
    _cf_path="$1"
    _cf_out="${2:-$TMP/SRC}"
    printf '%s\n' "$_cf_path" >> "$CLAN_CALLS"
    case "$CLAN_MODE:$_cf_path" in
        quest:/clan/99/quest/) printf '/quest/take/3/?r=12345\n' > "$_cf_out" ;;
        quest:/quest/take/3/?r=12345) printf 'ok\n' > "$_cf_out" ;;
        dungeon:/clandungeon/) printf '/clandungeon/executar\n' > "$_cf_out" ;;
        dungeon:/clandungeon/executar) printf '/clandungeon/attack/?r=1\n' > "$_cf_out" ;;
        dungeon:/clandungeon/attack/?r=*)
            DUN_ATTACKS=$((DUN_ATTACKS + 1))
            if [ "$DUN_ATTACKS" -lt 10 ]; then printf '/clandungeon/attack/?r=%s\n' "$((DUN_ATTACKS + 1))" > "$_cf_out"; else : > "$_cf_out"; fi ;;
        *) : > "$_cf_out" ;;
    esac
    unset _cf_path _cf_out
    return 0
}
. "$ROOT/clanid.sh"

: > "$CLAN_CALLS"
CLAN_MODE=quest
if checkQuest 3 apply >/dev/null 2>&1 && grep -q '^/quest/take/3/?r=12345$' "$CLAN_CALLS"; then ok 'checkQuest aceita token r com tamanho variavel'; else fail 'checkQuest ainda depende de token r com tamanho fixo'; fi

: > "$CLAN_CALLS"
CLAN_MODE=dungeon
DUN_ATTACKS=0
if clanDungeon >/dev/null 2>&1 && [ "$DUN_ATTACKS" -eq 10 ]; then
    if grep -q '^/clandungeon/executar$' "$CLAN_CALLS" && ! grep -qiE 'buy|pay|gold|purchase' "$CLAN_CALLS"; then ok 'Masmorra entra por executar e limita 10 ataques gratuitos'; else fail 'Masmorra usou fluxo inesperado/pago'; fi
else fail "Masmorra enviou ${DUN_ATTACKS:-0} ataques; esperado 10"; fi

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
        /demo/) printf "%s\n" "/demo/enterFight/?r=111" "/demo/enterFight/?r=222" > "$TMP/SRC" ;;
        /demo/enterFight/*) printf "logged\n" > "$TMP/SRC" ;;
        /inv/chest/) printf "/inv/chest/use/10/1/?r=1\n" > "$TMP/SRC"; ELIXIR_STEP=0 ;;
        /inv/chest/use/*)
            ELIXIR_STEP=$((ELIXIR_STEP + 1))
            case "$ELIXIR_STEP" in 1) printf "/inv/chest/use/11/1/?r=2\n" > "$TMP/SRC" ;; 2) printf "/inv/chest/use/12/1/?r=3\n" > "$TMP/SRC" ;; *) : > "$TMP/SRC" ;; esac ;;
        *) : > "$TMP/SRC" ;;
    esac
    unset _tf_path
    return 0
}
. "$ROOT/check.sh"

: > "$CALLS"
if apply_event "" >/dev/null 2>&1; then fail 'apply_event vazio retornou sucesso'; elif [ -s "$CALLS" ]; then fail 'apply_event vazio tentou requisicao'; else ok 'apply_event vazio falha sem requisicao fantasma'; fi
: > "$CALLS"
if apply_event demo >/dev/null 2>&1; then
    _n=`wc -l < "$CALLS" | tr -d ' '`
    if [ "$_n" -eq 2 ] && grep -q '^/demo/enterFight/?r=111$' "$CALLS"; then ok 'apply_event usa somente o primeiro link valido'; else fail 'apply_event enviou quantidade/link inesperado'; fi
else fail 'apply_event valido falhou no fixture offline'; fi
: > "$CALLS"
ELIXIR_STEP=0
if use_elixir >/dev/null 2>&1; then
    _uses=`grep -c '^/inv/chest/use/' "$CALLS" 2>/dev/null || true`
    if [ "$_uses" -eq 3 ]; then ok 'use_elixir processa a lista mutavel sem pular itens'; else fail "use_elixir enviou $_uses usos; esperado 3"; fi
else fail 'use_elixir falhou no fixture offline'; fi

TMP="$WORK/runner"
mkdir -p "$TMP"
export TMP
RUN_CALLS=0
fetch_page() { RUN_CALLS=$((RUN_CALLS + 1)); printf '/campaign/attack/?r=999\n' > "${2:-$TMP/SRC}"; return 0; }
priority_guard() { return 0; }
is_logged_in() { return 0; }
. "$ROOT/action_runner.sh"
if activity_run_links "/campaign/" '/campaign/attack/[?]r=[0-9]+' 30 fixture >/dev/null 2>&1; then
    fail 'action_runner aceitou acao eterna como progresso'
else
    if [ "${ACTIVITY_RUN_COUNT:-0}" -le 3 ]; then ok 'action_runner aborta repeticao sem progresso'; else fail 'action_runner demorou demais para abortar repeticao'; fi
fi

# ClanFight: parser e allowlist de acoes do proprio evento.
TMP="$WORK/clanfight"
mkdir -p "$TMP"
export TMP
cat > "$TMP/SRC" <<'EOF'
<a href='/clanfight/attack/?r=111'>Ataque</a>
<a href='/clanfight/attackrandom/?r=222'>Aleatorio</a>
<a href='/clanfight/dodge/?r=333'>Esquiva</a>
<a href='/clanfight/heal/?r=444'>Cura</a>
hp'>850
&nbsp;1200
EOF
. "$ROOT/clanfight.sh"
if clanfight_parse "$TMP/SRC" && [ "$CF_ATK" = '/clanfight/attack/?r=111' ] && [ "$CF_DODGE" = '/clanfight/dodge/?r=333' ]; then ok 'ClanFight reconhece acoes validas do evento'; else fail 'ClanFight nao reconheceu fixture de batalha'; fi
if clanfight_link_valido '/clanfight/heal/?r=444' && ! clanfight_link_valido '/trade/exchange/gold/100?r=1' && ! clanfight_link_valido ''; then ok 'ClanFight bloqueia URL vazia/fora do evento'; else fail 'ClanFight allowlist de URL falhou'; fi

# Scheduler fora do cronograma: o guard interno nao pode consultar cla a cada
# acao, e os marcadores precisam liberar/segurar tarefas no intervalo correto.
TMP="$WORK/scheduler"
mkdir -p "$TMP"
export TMP
TWMDIR="$ROOT"
export TWMDIR
. "$ROOT/priority.sh"
CLAN_PROBES=0
priority_event_window() { return 1; }
event_lock_active() { return 1; }
priority_clan_pending() { CLAN_PROBES=$((CLAN_PROBES + 1)); return 1; }
if priority_guard && [ "$CLAN_PROBES" -eq 0 ]; then ok 'guard interno nao consulta cla durante atividade'; else fail 'guard interno ainda consulta cla/reinterrompe atividade'; fi
rm -f "$TMP/last_missions"
if priority_task_due missions 300; then
    priority_task_mark missions
    if priority_task_due missions 300; then fail 'marcador de Missoes nao aplicou intervalo'; else ok 'Missoes fora do cronograma possuem intervalo funcional'; fi
else fail 'Missoes novas nasceram bloqueadas'; fi

printf '\nResultado runtime: %s OK | %s FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
