#!/bin/sh
# test_agent.sh - validacao estatica + testes offline V2.1.
# NAO faz login, NAO acessa o jogo e NAO executa atividades reais.

set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS + 1)); printf '[OK]   %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '[WARN] %s\n' "$*"; }

printf '=== Furia de Titas - auditoria segura V2.1 ===\n'

case "$(uname -s 2>/dev/null)" in
    Linux)
        if [ -d /data/data/com.termux ]; then
            ok 'plataforma: Android/Termux'
        elif grep -qi microsoft /proc/version 2>/dev/null; then
            ok 'plataforma: WSL'
        else
            warn 'plataforma Linux generica'
        fi
        ;;
    *) warn "plataforma nao validada: $(uname -s 2>/dev/null)" ;;
esac

# Presenca dos modulos centrais.
for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh clanquest.sh clanid.sh info.sh panel.sh panel_live.sh status.sh state.sh action_runner.sh resource_guard.sh test_agent_runtime.sh agent_manifest.json; do
    if [ -f "$ROOT/$f" ]; then ok "$f presente"; else fail "$f ausente"; fi
done

# Sintaxe de TODOS os scripts da raiz. Isto pega regressao em modulo antigo
# que ainda possa ser sourced pelo twm.sh, nao apenas os arquivos V2.
for _f in "$ROOT"/*.sh; do
    [ -f "$_f" ] || continue
    _bn=${_f##*/}
    if sh -n "$_f" 2>/dev/null; then
        ok "sintaxe sh: $_bn"
    else
        fail "erro de sintaxe sh: $_bn"
    fi
done
unset _f _bn

# O runtime deve falhar fechado se a V2 estiver incompleta; nunca cair no
# scheduler legado silenciosamente.
if grep -q 'fluxo legado desativado por seguranca' "$ROOT/run.sh" 2>/dev/null && \
   grep -q 'modulo obrigatorio ausente' "$ROOT/run.sh" 2>/dev/null; then
    ok 'run.sh falha fechado sem modulos V2'
else
    fail 'run.sh ainda pode cair em fluxo legado inseguro'
fi

if grep -q 'twm_play_priority_loader' "$ROOT/run.sh" 2>/dev/null && \
   grep -q '\. "$TWMDIR/priority.sh"' "$ROOT/run.sh" 2>/dev/null; then
    ok 'priority.sh carregado tardiamente'
else
    fail 'loader tardio de priority.sh ausente'
fi

# Gastos perigosos absolutos.
if grep -Eq '^use_blessing\(\)[[:space:]]*\{[[:space:]]*return 0;[[:space:]]*\}' "$ROOT/priority.sh" 2>/dev/null && \
   awk '/^use_blessing\(\)/,/^}/' "$ROOT/trade.sh" | grep -q 'return 0'; then
    ok 'bencao automatica bloqueada em duas camadas'
else
    fail 'bloqueio absoluto da bencao incompleto'
fi

if grep -q '^FUNC_use_blessing=n$' "$ROOT/function.sh" && \
   grep -q '^FUNC_cave_boost=n$' "$ROOT/function.sh" && \
   grep -q '^FUNC_quest_force_gold=n$' "$ROOT/function.sh"; then
    ok 'defaults perigosos desligados'
else
    fail 'defaults perigosos habilitados'
fi

# checkQuest legado nao pode mais selecionar help.
_cq_block=`awk '/^checkQuest\(\)/,/^}/' "$ROOT/clanid.sh"`
if printf '%s\n' "$_cq_block" | grep -q '/quest/take/' && \
   ! printf '%s\n' "$_cq_block" | grep -q 'take|help'; then
    ok 'checkQuest legado nao possui bypass /help'
else
    fail 'checkQuest ainda pode selecionar ajuda fora do guard'
fi
unset _cq_block

if grep -q '^cq_help_sem_ouro()' "$ROOT/clanquest.sh" && \
   grep -q 'gold\\.png\|gold\|ouro' "$ROOT/clanquest.sh" 2>/dev/null; then
    ok 'ajuda do cla inspeciona contexto por indicador de ouro'
else
    warn 'nao foi possivel confirmar filtro contextual da ajuda do cla'
fi

if awk '/^cq_forcar_ouro\(\)/,/^}/' "$ROOT/clanquest.sh" | grep -q 'return 1'; then
    ok 'conclusao forcada com ouro esta fail-closed'
else
    fail 'cq_forcar_ouro nao esta bloqueado'
fi

# Caverna e tesouraria.
if grep -q 'cave_gold_boost' "$ROOT/resource_guard.sh" && \
   ! grep -q 'fetch_page "$BOOST_LINK"' "$ROOT/cave.sh" 2>/dev/null; then
    ok 'boost de ouro da caverna bloqueado'
else
    fail 'caverna ainda pode chamar boost de ouro'
fi

if awk '/^clan_money\(\)/,/^}/' "$ROOT/trade.sh" | grep -q 'return 1' && \
   ! awk '/^clan_money\(\)/,/^}/' "$ROOT/trade.sh" | grep -q '/money/'; then
    ok 'tesouraria antiga desativada ate politica correta'
else
    fail 'tesouraria antiga ainda pode doar fora da politica'
fi

if awk '/^clan_statue\(\)/,/^}/' "$ROOT/clanid.sh" | grep -q 'return 1'; then
    ok 'estatua automatica fail-closed enquanto gasto nao e governado'
else
    fail 'estatua ainda pode gastar recursos sem guard'
fi

# Eventos: deduplicacao e sem falso "finished".
if grep -q '^priority_event_slot()' "$ROOT/priority.sh" && \
   grep -q 'event_slot_seen' "$ROOT/priority.sh" && \
   grep -q 'event_slot_mark' "$ROOT/priority.sh"; then
    ok 'evento possui identificador de janela e deduplicacao'
else
    fail 'evento pode repetir na mesma janela'
fi

if grep -q 'EVENT_LOCK_TTL' "$ROOT/state.sh" && grep -q 'event_lock_active' "$ROOT/state.sh"; then
    ok 'event_lock possui TTL contra lock fantasma'
else
    fail 'event_lock nao expira com seguranca'
fi

# O scheduler deve registrar apenas "returned" quando o modulo volta rc=0;
# nunca "finished" enquanto o fim semantico do evento nao for comprovado.
if grep -q 'priority_state cronograma /fights/timetable/ returned' "$ROOT/priority.sh" && \
   ! grep -q 'priority_state cronograma /fights/timetable/ finished' "$ROOT/priority.sh" && \
   ! grep -q 'event_lock_finish "$_ev" finished' "$ROOT/priority.sh"; then
    ok 'scheduler nao chama retorno de modulo de conclusao confirmada'
else
    fail 'scheduler ainda anuncia evento como concluido sem prova'
fi

# Arena: cooldown so apos verificacao valida (ataque ou nenhum ataque), nunca
# depois de falha/interrupcao.
if grep -q 'ARENA_ATTACKS=0' "$ROOT/arena.sh" && \
   grep -q '0|3) arena_marcar' "$ROOT/priority.sh"; then
    ok 'arena diferencia sucesso/sem-acao de falha antes do cooldown'
else
    fail 'cooldown da arena ainda pode ocultar falha'
fi

# Masmorra.
if grep -q '/clandungeon/executar' "$ROOT/clanid.sh" && \
   grep -q '/clandungeon/attack/' "$ROOT/clanid.sh" && \
   grep -q '"$_n" -lt 10' "$ROOT/clanid.sh"; then
    ok 'masmorra detecta executar e limita 10 golpes gratuitos'
else
    fail 'fluxo da masmorra incompleto'
fi

# Acoes fantasmas comuns.
if grep -q 'evento vazio ignorado' "$ROOT/check.sh" && \
   grep -q "sed -n '1p'" "$ROOT/check.sh"; then
    ok 'apply_event rejeita evento vazio e usa apenas um link'
else
    fail 'apply_event ainda aceita chamada fantasma/multipla'
fi

if grep -q 'Sempre usa o PRIMEIRO link atual' "$ROOT/check.sh"; then
    ok 'elixir processa lista mutavel sem pular indices'
else
    fail 'use_elixir ainda usa indice mutavel inseguro'
fi

if grep -q 'mesma acao repetida sem progresso' "$ROOT/action_runner.sh" && \
   grep -q 'acao %s enviada' "$ROOT/action_runner.sh"; then
    ok 'action_runner detecta ausencia de progresso e nao declara conclusao'
else
    fail 'action_runner ainda pode produzir progresso fantasma'
fi

if grep -q 'COLLECT_REWARDS_RUNTIME' "$ROOT/check.sh" && \
   grep -q 'COLLECT_REWARDS_RUNTIME' "$ROOT/function.sh"; then
    ok 'pausa de recompensa de fim de semana conectada ao consumidor'
else
    fail 'estado runtime de fim de semana nao esta conectado'
fi

if grep -q '_rc_track' "$ROOT/info.sh" && grep -q 'ler_arq "$_d/pagina"' "$ROOT/panel_live.sh"; then
    ok 'painel LIVE usa pagina realmente solicitada'
else
    fail 'painel LIVE nao esta ligado ao rastreio real de pagina'
fi

# Teste comportamental offline.
if [ -f "$ROOT/test_agent_runtime.sh" ]; then
    printf '\n--- executando testes offline ---\n'
    if sh "$ROOT/test_agent_runtime.sh"; then
        ok 'testes comportamentais offline passaram'
    else
        fail 'testes comportamentais offline falharam'
    fi
fi

printf '\nResultado auditoria: %s OK | %s WARN | %s FAIL\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
