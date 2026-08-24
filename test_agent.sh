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

for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh clanquest.sh clanid.sh info.sh panel.sh panel_live.sh; do
    check_file "$f"
done

# Sintaxe POSIX/sh dos arquivos centrais.
for f in play.sh worker.sh twm.sh run.sh priority.sh panel_live.sh; do
    if [ -f "$ROOT/$f" ]; then
        if sh -n "$ROOT/$f" 2>/dev/null; then
            ok "sintaxe sh: $f"
        else
            fail "erro de sintaxe sh: $f"
        fi
    fi
done

# A prioridade deve ser carregada somente em runtime, depois que todos os
# modulos ja foram sourced, para impedir que trade.sh redefina use_blessing.
if grep -q 'twm_play_priority_loader' "$ROOT/run.sh" 2>/dev/null && \
   grep -q '\. "$TWMDIR/priority.sh"' "$ROOT/run.sh" 2>/dev/null; then
    ok 'priority.sh carregado no momento correto'
else
    fail 'loader tardio de priority.sh nao encontrado'
fi

# Bencao: duas protecoes. A funcao do agente deve ser no-op e a variavel n.
if grep -Eq '^use_blessing\(\)[[:space:]]*\{[[:space:]]*return 0;[[:space:]]*\}' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'bencao bloqueada por override no-op'
else
    fail 'override absoluto de use_blessing ausente'
fi

if grep -q '^    FUNC_use_blessing=n$' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'FUNC_use_blessing forcado para n'
else
    fail 'FUNC_use_blessing nao esta forcado para n'
fi

# Confirma que o scheduler declara a ordem principal.
if grep -q 'priority_event_window' "$ROOT/priority.sh" && \
   grep -q 'priority_run_clan' "$ROOT/priority.sh" && \
   grep -q 'priority_secondary' "$ROOT/priority.sh"; then
    ok 'camadas de prioridade presentes: evento > cla > secundarias'
else
    fail 'camadas de prioridade incompletas'
fi

# Caverna: boost de ouro deve ser forcado para n no agente.
if grep -q '^    FUNC_cave_boost=n$' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'boost de ouro da caverna desativado no agente'
else
    fail 'boost de ouro da caverna nao esta bloqueado'
fi

# Masmorra: rotina explicitamente limitada aos links de ataques gratuitos.
if grep -q 'SOMENTE GOLPES GRATUITOS' "$ROOT/clanid.sh" 2>/dev/null && \
   grep -q '/clandungeon/attack/' "$ROOT/clanid.sh" 2>/dev/null; then
    ok 'masmorra configurada para golpes gratuitos'
else
    fail 'regra de golpes gratuitos da masmorra nao confirmada'
fi

# Painel: pagina real deve vir do rastreamento central de requisicoes.
if grep -q '_rc_track' "$ROOT/info.sh" 2>/dev/null && \
   grep -q 'ler_arq "$_d/pagina"' "$ROOT/panel_live.sh" 2>/dev/null; then
    ok 'painel LIVE usa pagina real por conta'
else
    fail 'rastreamento de pagina LIVE incompleto'
fi

printf '\nResultado: %s OK | %s WARN | %s FAIL\n' "$PASS" "$WARN" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
