#!/bin/sh
# test_agent.sh - validacao estatica/segura do agente de automacao.
# NAO faz login, NAO acessa o jogo e NAO executa atividades.

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
PASS=0
FAIL=0
WARN=0

ok()   { PASS=$((PASS + 1)); printf '[OK]   %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '[FAIL] %s\n' "$*"; }
warn() { WARN=$((WARN + 1)); printf '[WARN] %s\n' "$*"; }

check_file() {
    [ -f "$ROOT/$1" ] && ok "$1 presente" || fail "$1 ausente"
}

printf '=== Furia de Titas - teste seguro do agente ===\n'

case "$(uname -s 2>/dev/null)" in
    Linux)
        if [ -d /data/data/com.termux ]; then
            ok 'plataforma: Android/Termux'
        elif grep -qi microsoft /proc/version 2>/dev/null; then
            ok 'plataforma: WSL'
        else
            warn 'plataforma Linux generica (teste ainda aplicavel)'
        fi
        ;;
    *) warn "plataforma nao validada: $(uname -s 2>/dev/null)" ;;
esac

for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh clanquest.sh clanid.sh info.sh panel.sh panel_live.sh coliseum.sh status.sh; do
    check_file "$f"
done

for f in play.sh worker.sh twm.sh run.sh priority.sh trade.sh clanquest.sh clanid.sh panel_live.sh coliseum.sh status.sh; do
    if [ -f "$ROOT/$f" ]; then
        if sh -n "$ROOT/$f" 2>/dev/null; then
            ok "sintaxe sh: $f"
        else
            fail "erro de sintaxe sh: $f"
        fi
    fi
done

if grep -q 'git -C.*show' "$ROOT/play.sh" 2>/dev/null; then
    fail 'play.sh ainda depende de git show em runtime'
else
    ok 'play.sh independente de git em runtime'
fi

if grep -q 'twm_play_priority_loader' "$ROOT/run.sh" 2>/dev/null && \
   grep -q '\. "$TWMDIR/priority.sh"' "$ROOT/run.sh" 2>/dev/null; then
    ok 'priority.sh carregado no momento correto'
else
    fail 'loader tardio de priority.sh nao encontrado'
fi

if grep -Eq '^use_blessing\(\)[[:space:]]*\{[[:space:]]*return 0;[[:space:]]*\}' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'bencao bloqueada no scheduler'
else
    fail 'override absoluto de use_blessing ausente em priority.sh'
fi

if awk '/^use_blessing\(\)/,/^}/' "$ROOT/trade.sh" 2>/dev/null | grep -q 'return 0' && \
   ! awk '/^use_blessing\(\)/,/^}/' "$ROOT/trade.sh" 2>/dev/null | grep -q 'effshop/blessing'; then
    ok 'bencao bloqueada na funcao de origem; sem URL de compra'
else
    fail 'trade.sh ainda permite compra de bencao'
fi

if grep -q '^    FUNC_use_blessing=n$' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'FUNC_use_blessing forcado para n'
else
    fail 'FUNC_use_blessing nao esta forcado para n'
fi

if grep -q 'priority_event_window' "$ROOT/priority.sh" && \
   grep -q 'priority_run_clan' "$ROOT/priority.sh" && \
   grep -q 'priority_secondary' "$ROOT/priority.sh"; then
    ok 'camadas de prioridade presentes: evento > cla > secundarias'
else
    fail 'camadas de prioridade incompletas'
fi

if grep -q '(end|deleteHelp)' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'missao do cla ativa reconhecida pelo scheduler'
else
    fail 'scheduler nao reconhece missao do cla ativa'
fi

if grep -q 'Ajuda paga ignorada' "$ROOT/clanquest.sh" 2>/dev/null; then
    ok 'ajuda paga de missao do cla ignorada'
else
    fail 'bloqueio de ajuda paga nao encontrado'
fi

if grep -q '^    FUNC_quest_force_gold=n$' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'conclusao automatica de missao com ouro bloqueada'
else
    fail 'FUNC_quest_force_gold nao esta bloqueado'
fi

if grep -q '^    FUNC_cave_boost=n$' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'boost de ouro da caverna desativado no agente'
else
    fail 'boost de ouro da caverna nao esta bloqueado'
fi

# Masmorra: somente golpes gratuitos, no maximo 10, e marcador apenas apos
# ataque real. Isso evita o falso "executado" quando a pagina nao respondeu.
if grep -q 'SOMENTE GOLPES GRATUITOS' "$ROOT/clanid.sh" 2>/dev/null && \
   grep -q '/clandungeon/attack/' "$ROOT/clanid.sh" 2>/dev/null && \
   grep -q '"$_n" -lt 10' "$ROOT/clanid.sh" 2>/dev/null; then
    ok 'masmorra limitada a ate 10 golpes gratuitos'
else
    fail 'limite gratuito da masmorra nao confirmado'
fi

if grep -q 'if clanDungeon; then' "$ROOT/priority.sh" 2>/dev/null && \
   grep -A5 'if clanDungeon; then' "$ROOT/priority.sh" 2>/dev/null | grep -q 'masmorra_marcar'; then
    ok 'masmorra so e marcada apos execucao real'
else
    fail 'scheduler pode marcar masmorra sem executar ataques'
fi

# Painel LIVE: fonte unica deve ser o caminho real registrado por info.sh.
if grep -q '_rc_track' "$ROOT/info.sh" 2>/dev/null && \
   grep -q 'ler_arq "$_d/pagina"' "$ROOT/panel_live.sh" 2>/dev/null && \
   ! grep -q 'priority_state.*aba_de' "$ROOT/panel_live.sh" 2>/dev/null; then
    ok 'painel LIVE usa somente pagina real por conta'
else
    fail 'painel LIVE nao esta isolado do estado interno do scheduler'
fi

# /clan/* deve aparecer como Cla; /clandungeon/* como Masmorra; descanso /.
if grep -q '/clandungeon.*Masmorra' "$ROOT/panel_live.sh" 2>/dev/null && \
   grep -q '/clan\*.*Clã' "$ROOT/panel_live.sh" 2>/dev/null && \
   grep -q 'Página Principal' "$ROOT/panel_live.sh" 2>/dev/null; then
    ok 'nomes LIVE coerentes: Pagina Principal, Cla e Masmorra'
else
    fail 'mapeamento principal/cla/masmorra incompleto'
fi

# O descanso precisa ser uma requisicao real a /, nao apenas um rotulo.
if grep -q 'descansar 2>/dev/null' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'descanso retorna de fato para a pagina principal'
else
    fail 'scheduler nao retorna de fato para a pagina principal'
fi

# Relatorio do Coliseu deve ser apagado no fim, e painel nao pode mostrar HP
# antigo quando a conta ja saiu da pagina de batalha.
if grep -q 'col_report_clear' "$ROOT/coliseum.sh" 2>/dev/null && \
   grep -q 'Fim da luta' "$ROOT/coliseum.sh" 2>/dev/null && \
   grep -q '/coliseum\*)' "$ROOT/panel_live.sh" 2>/dev/null; then
    ok 'relatorio de batalha e transitorio e some apos o fim'
else
    fail 'limpeza de relatorio de batalha nao confirmada'
fi

printf '\nResultado: %s OK | %s WARN | %s FAIL\n' "$PASS" "$WARN" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
