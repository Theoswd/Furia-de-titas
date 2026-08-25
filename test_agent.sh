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

printf '=== Furia de Titas - teste seguro do agente V2 ===\n'

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

for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh clanquest.sh clanid.sh info.sh panel.sh panel_live.sh coliseum.sh status.sh state.sh action_runner.sh resource_guard.sh agent_manifest.json; do
    check_file "$f"
done

for f in play.sh worker.sh twm.sh run.sh priority.sh function.sh trade.sh clanquest.sh clanid.sh info.sh panel.sh panel_live.sh coliseum.sh status.sh state.sh action_runner.sh resource_guard.sh arena.sh campaign.sh career.sh cave.sh specialevent.sh; do
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

if grep -q 'twm_play_priority_loader' "$ROOT/run.sh" 2>/dev/null && grep -q '\. "$TWMDIR/priority.sh"' "$ROOT/run.sh" 2>/dev/null; then
    ok 'priority.sh carregado no momento correto'
else
    fail 'loader tardio de priority.sh nao encontrado'
fi

if grep -Eq '^use_blessing\(\)[[:space:]]*\{[[:space:]]*return 0;[[:space:]]*\}' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'bencao bloqueada no scheduler'
else
    fail 'override absoluto de use_blessing ausente em priority.sh'
fi

if awk '/^use_blessing\(\)/,/^}/' "$ROOT/trade.sh" 2>/dev/null | grep -q 'return 0' && ! awk '/^use_blessing\(\)/,/^}/' "$ROOT/trade.sh" 2>/dev/null | grep -q 'effshop/blessing'; then
    ok 'bencao bloqueada na funcao de origem; sem URL de compra'
else
    fail 'trade.sh ainda permite compra de bencao'
fi

if grep -q '^FUNC_use_blessing=n$' "$ROOT/function.sh" 2>/dev/null && grep -q '^FUNC_cave_boost=n$' "$ROOT/function.sh" 2>/dev/null && grep -q '^FUNC_quest_force_gold=n$' "$ROOT/function.sh" 2>/dev/null; then
    ok 'defaults economicos perigosos desligados'
else
    fail 'defaults perigosos ainda habilitados'
fi

if grep -q 'priority_event_window' "$ROOT/priority.sh" && grep -q 'priority_run_clan' "$ROOT/priority.sh" && grep -q 'priority_secondary' "$ROOT/priority.sh"; then
    ok 'camadas de prioridade presentes: evento > cla > secundarias'
else
    fail 'camadas de prioridade incompletas'
fi

if grep -q 'event_lock_start' "$ROOT/priority.sh" 2>/dev/null && grep -q 'event_lock_active' "$ROOT/priority.sh" 2>/dev/null && grep -q 'event_lock_finish' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'event_lock integrado ao cronograma'
else
    fail 'event_lock nao integrado ao scheduler'
fi

if grep -q 'runtime_state_write' "$ROOT/priority.sh" 2>/dev/null && grep -q '^runtime_state_write()' "$ROOT/state.sh" 2>/dev/null; then
    ok 'runtime_state V2 integrado'
else
    fail 'runtime_state V2 ausente'
fi

if grep -q '^activity_run_links()' "$ROOT/action_runner.sh" 2>/dev/null && grep -q 'priority_guard' "$ROOT/action_runner.sh" 2>/dev/null; then
    ok 'action_runner sequencial e preemptivel presente'
else
    fail 'action_runner incompleto'
fi

if grep -q 'activity_run_links' "$ROOT/campaign.sh" 2>/dev/null && grep -q 'activity_run_links' "$ROOT/career.sh" 2>/dev/null; then
    ok 'campanha e carreira usam executor V2'
else
    fail 'executor V2 nao integrado em campanha/carreira'
fi

if grep -q 'Ajuda paga ignorada' "$ROOT/clanquest.sh" 2>/dev/null; then
    ok 'ajuda paga de missao do cla ignorada'
else
    fail 'bloqueio de ajuda paga nao encontrado'
fi

if grep -q 'cave_gold_boost' "$ROOT/resource_guard.sh" 2>/dev/null && grep -q 'cave_gold_boost' "$ROOT/cave.sh" 2>/dev/null && ! grep -q 'fetch_page "$BOOST_LINK"' "$ROOT/cave.sh" 2>/dev/null; then
    ok 'boost de ouro da caverna bloqueado por politica e implementacao'
else
    fail 'caverna ainda pode executar boost de ouro'
fi

if grep -q '/clandungeon/executar' "$ROOT/clanid.sh" 2>/dev/null && grep -q '/clandungeon/attack/' "$ROOT/clanid.sh" 2>/dev/null && grep -q '"$_n" -lt 10' "$ROOT/clanid.sh" 2>/dev/null; then
    ok 'masmorra detecta executar e limita a ate 10 golpes gratuitos'
else
    fail 'fluxo seguro da masmorra incompleto'
fi

if grep -q 'if clanDungeon; then' "$ROOT/priority.sh" 2>/dev/null && grep -A5 'if clanDungeon; then' "$ROOT/priority.sh" 2>/dev/null | grep -q 'masmorra_marcar'; then
    ok 'masmorra so e marcada apos execucao real'
else
    fail 'scheduler pode marcar masmorra sem executar ataques'
fi

if grep -q 'while grep.*&&.*BREAK' "$ROOT/arena.sh" 2>/dev/null || grep -q 'while grep -q -o.*&& \[.*BREAK' "$ROOT/arena.sh" 2>/dev/null; then
    ok 'arena_fault exige link e timeout valido'
else
    warn 'nao foi possivel confirmar estaticamente a condicao AND de arena_fault'
fi

if grep -q 'FUNC_arena_sell_all:-n' "$ROOT/arena.sh" 2>/dev/null; then
    ok 'sellAll da arena e opt-in'
else
    fail 'arena ainda vende inventario sem politica opt-in'
fi

if grep -q 'cedendo ao cronograma de batalhas' "$ROOT/specialevent.sh" 2>/dev/null && grep -q '\[ -n "$click" \] || return 1' "$ROOT/specialevent.sh" 2>/dev/null; then
    ok 'evento especial valida link e cede ao cronograma'
else
    fail 'preempcao/validacao do evento especial incompleta'
fi

if grep -q '_rc_track' "$ROOT/info.sh" 2>/dev/null && grep -q 'ler_arq "$_d/pagina"' "$ROOT/panel_live.sh" 2>/dev/null; then
    ok 'painel LIVE continua usando pagina real por conta'
else
    fail 'painel LIVE nao esta ligado a pagina real'
fi

if grep -q 'descansar 2>/dev/null' "$ROOT/priority.sh" 2>/dev/null; then
    ok 'descanso retorna de fato para a pagina principal'
else
    fail 'scheduler nao retorna de fato para a pagina principal'
fi

if grep -q 'col_report_clear' "$ROOT/coliseum.sh" 2>/dev/null && grep -q 'Fim da luta' "$ROOT/coliseum.sh" 2>/dev/null; then
    ok 'relatorio de batalha do Coliseu e transitorio'
else
    fail 'limpeza de relatorio do Coliseu nao confirmada'
fi

printf '\nResultado: %s OK | %s WARN | %s FAIL\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
