#!/bin/sh
# test_agent.sh - validacao estatica + testes offline V2.1.2.
# NAO faz login, NAO acessa o jogo e NAO executa atividades reais.

set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS + 1)); printf '[OK]   %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '[WARN] %s\n' "$*"; }

printf '=== Furia de Titas - auditoria segura V2.1.2 ===\n'

case "$(uname -s 2>/dev/null)" in
    Linux)
        if [ -d /data/data/com.termux ]; then ok 'plataforma: Android/Termux';
        elif grep -qi microsoft /proc/version 2>/dev/null; then ok 'plataforma: WSL';
        else warn 'plataforma Linux generica'; fi ;;
    *) warn "plataforma nao validada: $(uname -s 2>/dev/null)" ;;
esac

for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh blessing.sh clanquest.sh clanid.sh clanfight.sh crono.sh info.sh panel.sh panel_live.sh status.sh state.sh action_runner.sh resource_guard.sh test_agent_runtime.sh agent_manifest.json; do
    if [ -f "$ROOT/$f" ]; then ok "$f presente"; else fail "$f ausente"; fi
done

for _f in "$ROOT"/*.sh; do
    [ -f "$_f" ] || continue
    _bn=${_f##*/}
    if sh -n "$_f" 2>/dev/null; then ok "sintaxe sh: $_bn"; else fail "erro de sintaxe sh: $_bn"; fi
done
unset _f _bn

if grep -q 'fluxo legado desativado por seguranca' "$ROOT/run.sh" 2>/dev/null && \
   grep -q 'modulo obrigatorio ausente' "$ROOT/run.sh" 2>/dev/null; then
    ok 'run.sh falha fechado sem modulos V2'
else
    fail 'run.sh ainda pode cair em fluxo legado inseguro'
fi

if grep -q '\. "$TWMDIR/priority.sh"' "$ROOT/run.sh" && grep -q '\. "$TWMDIR/blessing.sh"' "$ROOT/run.sh"; then
    ok 'priority e bloqueio da Bencao carregados no final'
else
    fail 'ordem final de priority/blessing incompleta'
fi

if grep -q '/effshop/blessing/' "$ROOT/blessing.sh" && \
   grep -q 'blessing_url_bloqueada' "$ROOT/blessing.sh" && \
   ! grep -q 'use_blessing' "$ROOT/crono.sh"; then
    ok 'Bencao removida do fluxo e endpoint protegido'
else
    fail 'Bencao ainda pode estar ligada ao fluxo legado'
fi

if grep -q '^FUNC_use_blessing=n$' "$ROOT/function.sh" && \
   grep -q '^FUNC_cave_boost=n$' "$ROOT/function.sh" && \
   grep -q '^FUNC_quest_force_gold=n$' "$ROOT/function.sh"; then
    ok 'defaults perigosos desligados'
else
    fail 'defaults perigosos habilitados'
fi

_cq_block=`awk '/^checkQuest\(\)/,/^}/' "$ROOT/clanid.sh"`
if printf '%s\n' "$_cq_block" | grep -q '/quest/take/' && \
   printf '%s\n' "$_cq_block" | grep -q '\[0-9\]\+' && \
   ! printf '%s\n' "$_cq_block" | grep -q 'take|help'; then
    ok 'checkQuest sem /help e sem token r de tamanho fixo'
else
    fail 'checkQuest possui regressao em ajuda/token'
fi
unset _cq_block

if grep -q '^cq_help_sem_ouro()' "$ROOT/clanquest.sh" && grep -q 'gold\\.png\|gold\|ouro' "$ROOT/clanquest.sh"; then
    ok 'ajuda do cla inspeciona contexto por indicador de ouro'
else
    warn 'nao foi possivel confirmar filtro contextual da ajuda do cla'
fi

if awk '/^cq_forcar_ouro\(\)/,/^}/' "$ROOT/clanquest.sh" | grep -q 'return 1'; then ok 'conclusao forcada com ouro fail-closed'; else fail 'cq_forcar_ouro nao esta bloqueado'; fi

if grep -q 'cave_gold_boost' "$ROOT/resource_guard.sh" && ! grep -q 'fetch_page "$BOOST_LINK"' "$ROOT/cave.sh" 2>/dev/null; then ok 'boost de ouro da caverna bloqueado'; else fail 'caverna ainda pode chamar boost de ouro'; fi

if awk '/^clan_money\(\)/,/^}/' "$ROOT/trade.sh" | grep -q 'return 1' && ! awk '/^clan_money\(\)/,/^}/' "$ROOT/trade.sh" | grep -q '/money/'; then ok 'tesouraria antiga desativada'; else fail 'tesouraria antiga ainda ativa'; fi

if awk '/^clan_statue\(\)/,/^}/' "$ROOT/clanid.sh" | grep -q 'return 1'; then ok 'estatua automatica fail-closed'; else fail 'estatua ainda pode gastar recursos'; fi

if grep -q '^priority_event_slot()' "$ROOT/priority.sh" && grep -q 'event_slot_seen' "$ROOT/priority.sh" && grep -q 'event_slot_mark' "$ROOT/priority.sh"; then ok 'evento possui deduplicacao por janela'; else fail 'evento pode repetir na mesma janela'; fi

if grep -q 'EVENT_LOCK_TTL' "$ROOT/state.sh"; then ok 'event_lock possui TTL'; else fail 'event_lock sem TTL'; fi

if grep -q 'priority_state cronograma /fights/timetable/ returned' "$ROOT/priority.sh" && ! grep -q 'priority_state cronograma /fights/timetable/ finished' "$ROOT/priority.sh"; then ok 'scheduler nao finge conclusao confirmada'; else fail 'scheduler anuncia conclusao sem prova'; fi

if grep -q 'ARENA_ATTACKS=0' "$ROOT/arena.sh" && grep -q '0|3) arena_marcar' "$ROOT/priority.sh" && grep -q '0|3) arena_marcar' "$ROOT/crono.sh"; then ok 'Arena so marca cooldown em retorno valido'; else fail 'Arena pode marcar cooldown apos falha'; fi

if grep -q '/clandungeon/executar' "$ROOT/clanid.sh" && grep -q '"$_n" -lt 10' "$ROOT/clanid.sh" && grep -q 'if clanDungeon; then' "$ROOT/crono.sh"; then ok 'Masmorra: executar, limite 10 e marcador condicionado'; else fail 'fluxo da Masmorra incompleto'; fi

# ClanFight: sem URL vazia, fim normal separado de timeout e estado LIVE.
if grep -q '^clanfight_link_valido()' "$ROOT/clanfight.sh" && \
   grep -q 'timeout sem prova de fim' "$ROOT/clanfight.sh" && \
   grep -q 'return 4' "$ROOT/clanfight.sh" && \
   grep -q 'combat_state_write clanfight fighting' "$ROOT/clanfight.sh" && \
   ! grep -q 'ClanFight ok' "$ROOT/clanfight.sh"; then
    ok 'ClanFight valida links, distingue timeout e publica estado real'
else
    fail 'ClanFight ainda possui falso sucesso ou acao insegura'
fi

# O guard interno nao pode consultar missao do cla a cada ataque.
_pg_block=`awk '/^priority_guard\(\)/,/^}/' "$ROOT/priority.sh"`
if ! printf '%s\n' "$_pg_block" | grep -q 'priority_clan_pending' && \
   printf '%s\n' "$_pg_block" | grep -q 'priority_event_window'; then
    ok 'guard interno nao interrompe atividade por consulta repetida ao cla'
else
    fail 'guard interno ainda pode bloquear a propria missao/atividade'
fi
unset _pg_block

if grep -q '^priority_before_secondary()' "$ROOT/priority.sh" && \
   grep -q 'priority_task_due missions 300' "$ROOT/priority.sh" && \
   grep -q 'priority_task_due routine 600' "$ROOT/priority.sh" && \
   grep -q 'priority_task_due coliseum 300' "$ROOT/priority.sh"; then
    ok 'atividades fora do cronograma possuem cadencia e checagem de cla antes de executar'
else
    fail 'scheduler secundario ainda pode deixar atividades paradas'
fi

# Missoes gerais precisam aparecer antes do Coliseu no arquivo, para a janela
# noturna nao monopolizar a conta durante horas.
_mline=`grep -n 'priority_task_due missions 300' "$ROOT/priority.sh" | sed -n '1s/:.*//p'`
_cline=`grep -n 'priority_task_due coliseum 300' "$ROOT/priority.sh" | sed -n '1s/:.*//p'`
case "$_mline:$_cline" in
    *[!0-9:]*|:*) fail 'nao foi possivel validar ordem Missoes/Coliseu' ;;
    *) if [ "$_mline" -lt "$_cline" ]; then ok 'Missoes gerais sao verificadas antes do Coliseu'; else fail 'Coliseu ainda antecede Missoes gerais'; fi ;;
esac
unset _mline _cline

if grep -q 'evento vazio ignorado' "$ROOT/check.sh" && grep -q "sed -n '1p'" "$ROOT/check.sh"; then ok 'apply_event rejeita evento vazio e usa um link'; else fail 'apply_event inseguro'; fi

if grep -q 'Sempre usa o PRIMEIRO link atual' "$ROOT/check.sh"; then ok 'elixir processa lista mutavel'; else fail 'use_elixir pode pular item'; fi

if grep -q 'mesma acao repetida sem progresso' "$ROOT/action_runner.sh" && grep -q 'acao %s enviada' "$ROOT/action_runner.sh"; then ok 'action_runner detecta ausencia de progresso'; else fail 'action_runner pode produzir progresso fantasma'; fi

if grep -q 'COLLECT_REWARDS_RUNTIME' "$ROOT/check.sh" && grep -q 'COLLECT_REWARDS_RUNTIME' "$ROOT/function.sh"; then ok 'pausa de recompensa conectada'; else fail 'pausa de recompensa desconectada'; fi

if grep -q '_rc_track' "$ROOT/info.sh" && grep -q 'ler_arq "$_d/pagina"' "$ROOT/panel_live.sh"; then ok 'painel LIVE usa pagina realmente solicitada'; else fail 'painel LIVE sem rastreio real'; fi

if [ -f "$ROOT/test_agent_runtime.sh" ]; then
    printf '\n--- executando testes offline ---\n'
    if sh "$ROOT/test_agent_runtime.sh"; then ok 'testes comportamentais offline passaram'; else fail 'testes comportamentais offline falharam'; fi
fi

printf '\nResultado auditoria: %s OK | %s WARN | %s FAIL\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
