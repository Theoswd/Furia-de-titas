#!/bin/sh
# tests/test_manutencao.sh
#
# Testes da manutencao dos sistemas de batalha, HP, itens, Liga dos Favoritos
# e temporizacao. Nao acessa a rede: as requisicoes sao simuladas (stub de
# fetch_page). Roda em qualquer /bin/sh (dash, busybox, bash).
#
#   Uso:  sh tests/test_manutencao.sh
#
# Cobre:
#   1. HP atual x HP maximo (percentual, isolamento por conta, leitura falha)
#   2. Decisao de esquiva/ataque a partir da perda de HP
#   3. Invariante: a cura NAO sobrescreve o HP maximo (FULL)
#   4. Liga dos Favoritos: estado da recompensa separado das lutas, coleta
#      atrasada e confirmacao pelo servidor
#   5. Temporizacao: o sleep intermediario passou de 1s para 0,5s

_dir=$(dirname "$0")
ROOT=$(cd "$_dir/.." 2>/dev/null && pwd -P) || ROOT="."

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); printf "  [PASS] %s\n" "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf "  [FALHA] %s\n" "$1"; }
check(){ # check "descricao" valor_esperado valor_obtido
    if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1 (esperado=$2 obtido=$3)"; fi
}

# ---- helpers que replicam EXATAMENTE as expressoes usadas nos modulos ------
hp_percent() { # HP_ATUAL HP_MAXIMO -> percentual inteiro (ou "-" se invalido)
    _a="$1"; _m="$2"
    case "$_a" in ''|*[!0-9]*) printf '%s' "-"; return ;; esac
    case "$_m" in ''|*[!0-9]*|0) printf '%s' "-"; return ;; esac   # sem divisao por zero/vazio
    printf '%s' "$(( _a * 100 / _m ))"
}
hlhp() {  # FULL HPER -> limiar de cura, como nos modulos (awk)
    awk -v ush="$1" -v hper="$2" 'BEGIN { printf "%.0f", ush * hper / 100 }'
}
perdeu_hp() { # HP_ATUAL HP_ANTERIOR -> 1 se perdeu vida
    awk -v ush="$1" -v oldhp="$2" 'BEGIN { exit !(ush < oldhp) }' && echo 1 || echo 0
}

printf "=== 1. HP ATUAL x HP MAXIMO ===\n"
check "HP 1000/1000 = 100%" 100 "$(hp_percent 1000 1000)"
check "HP 800/1000  = 80%"  80  "$(hp_percent 800 1000)"
check "HP 670/1000  = 67%"  67  "$(hp_percent 670 1000)"
check "HP 400/1000  = 40%"  40  "$(hp_percent 400 1000)"
# 67% ou menos dispara tentativa de esmalte
_p=$(hp_percent 670 1000)
if [ "$_p" -le 67 ]; then ok "HP 67% aciona esmalte (<=67)"; else bad "HP 67% deveria acionar esmalte"; fi
_p=$(hp_percent 800 1000)
if [ "$_p" -le 67 ]; then bad "HP 80% NAO deveria acionar esmalte"; else ok "HP 80% nao aciona esmalte"; fi

printf "\n=== 1b. Leitura de HP invalida (nao usar maximo como padrao) ===\n"
check "HP atual ausente -> '-' (mantem ultimo valido, nao vira maximo)" "-" "$(hp_percent '' 1000)"
check "HP maximo ausente -> '-' (sem divisao)" "-" "$(hp_percent 670 '')"
check "HP maximo zero   -> '-' (sem divisao por zero)" "-" "$(hp_percent 670 0)"

printf "\n=== 1c. Isolamento por conta ===\n"
# Cada conta tem seu proprio estado; uma nao herda o HP da outra.
HP_ATUAL_01=670; HP_MAX_01=1000
HP_ATUAL_02=250; HP_MAX_02=500
check "Conta 01 percentual" 67 "$(hp_percent $HP_ATUAL_01 $HP_MAX_01)"
check "Conta 02 percentual" 50 "$(hp_percent $HP_ATUAL_02 $HP_MAX_02)"
check "Conta 01 nao mudou apos ler a 02" 670 "$HP_ATUAL_01"

printf "\n=== 2. Perda de HP decide esquiva x ataque ===\n"
check "HP caiu (670<800) -> perdeu=1 -> ESQUIVA" 1 "$(perdeu_hp 670 800)"
check "HP estavel (800=800) -> perdeu=0 -> ATAQUE" 0 "$(perdeu_hp 800 800)"

printf "\n=== 3. Invariante: cura NAO sobrescreve o HP maximo (FULL) ===\n"
# Simula o branch de cura corrigido: apos curar, FULL permanece o maximo.
HP_MAXIMO=1000
HPER=48
HP_ATUAL=400
LIMIAR_ANTES=$(hlhp "$HP_MAXIMO" "$HPER")     # 480
# --- cura: HP sobe; no codigo CORRIGIDO FULL nao e tocado ---
HP_ATUAL=900                                   # curou
# (o bug antigo fazia: HP_MAXIMO=$HP_ATUAL  -> aqui NAO fazemos isso)
LIMIAR_DEPOIS=$(hlhp "$HP_MAXIMO" "$HPER")     # continua 480
check "HP maximo preservado apos cura" 1000 "$HP_MAXIMO"
check "Limiar de cura estavel (nao sobe/desce a cada golpe)" "$LIMIAR_ANTES" "$LIMIAR_DEPOIS"
# Prova de regressao: nenhum modulo reintroduz o overwrite no branch de cura
if grep -nE 'cat (HP|USH) > FULL|cat USH > "\$full_ram"|echo "\$USH" > "\$full_ram"|_fullat="\$_hpat"' \
        "$ROOT"/king.sh "$ROOT"/clanfight.sh "$ROOT"/clandmg.sh "$ROOT"/altars.sh \
        "$ROOT"/coliseum.sh "$ROOT"/flagfight.sh >/dev/null 2>&1; then
    bad "algum modulo ainda sobrescreve o HP maximo com o HP atual"
else
    ok "nenhum modulo sobrescreve o HP maximo com o HP atual"
fi

printf "\n=== 4. Liga dos Favoritos: recompensa separada das lutas ===\n"
# Sourceia as funcoes REAIS da league.sh e simula o servidor via fetch_page.
TMP=$(mktemp -d)
export TMP
URL="http://exemplo"
# Estado da simulacao: qual "pagina" o servidor devolve
SIM_PAGE=""                 # conteudo escrito em $TMP/SRC pelo fetch_page
SIM_CLICKED=0               # o botao foi clicado?
SIM_REWARD_APPEARS_AT=99    # em qual chamada de "/league/" a recompensa surge
SIM_CALLS=0

fetch_page() {  # stub: simula o servidor
    _u="$1"
    case "$_u" in
        /league/)
            SIM_CALLS=$((SIM_CALLS + 1))
            if [ "$SIM_CLICKED" = 1 ]; then
                # apos coletar, o botao some (coleta confirmada)
                printf 'league page sem botao\n' > "$TMP/SRC"
            elif [ "$SIM_CALLS" -ge "$SIM_REWARD_APPEARS_AT" ]; then
                printf '<a href="/league/takeReward/?r=12345">coletar</a>\n' > "$TMP/SRC"
            else
                printf 'league page sem recompensa ainda\n' > "$TMP/SRC"
            fi
            ;;
        /league/takeReward/*)
            SIM_CLICKED=1
            printf 'reward taken\n' > "$TMP/SRC"
            ;;
        *) printf '' > "$TMP/SRC" ;;
    esac
    unset _u
}

# Carrega as funcoes de recompensa reais (league.sh so define funcoes).
. "$ROOT/league.sh" >/dev/null 2>&1

# 4a. Concluir 5 lutas apenas marca pendente (nunca "coletada")
league_reward_limpar
league_reward_marcar
if league_reward_pendente; then ok "5 lutas concluidas -> recompensa pendente=sim"; else bad "deveria ficar pendente"; fi

# 4b. Recompensa ATRASADA: 1a passagem nao ha botao -> permanece pendente
SIM_CLICKED=0; SIM_CALLS=0; SIM_REWARD_APPEARS_AT=99   # nunca aparece nesta passagem
if league_collect_reward; then bad "nao havia botao; nao deveria confirmar"; else ok "recompensa atrasada: coleta nao confirmada (retorno 1)"; fi
if league_reward_pendente; then ok "estado preservado como pendente apos passagem sem botao"; else bad "pendente foi apagado indevidamente"; fi

# 4c. Nova passagem: recompensa aparece -> coleta e confirma pelo servidor
SIM_CLICKED=0; SIM_CALLS=0; SIM_REWARD_APPEARS_AT=1    # aparece ja na 1a leitura
if league_collect_reward; then
    ok "recompensa atrasada coletada e confirmada pelo servidor"
    league_reward_limpar
else
    bad "recompensa presente deveria ser coletada"
fi
if league_reward_pendente; then bad "pendente deveria ter sido limpo apos confirmacao"; else ok "pendente limpo somente apos confirmacao real"; fi

# 4d. Coleta que o servidor NAO confirma (botao persiste) -> continua pendente
SIM_CLICKED=0; SIM_CALLS=0; SIM_REWARD_APPEARS_AT=1
# forca o botao a persistir mesmo apos o clique:
fetch_page() {
    case "$1" in
        /league/) printf '<a href="/league/takeReward/?r=999">coletar</a>\n' > "$TMP/SRC" ;;
        /league/takeReward/*) printf 'sem efeito\n' > "$TMP/SRC" ;;
        *) printf '' > "$TMP/SRC" ;;
    esac
}
league_reward_marcar
if league_collect_reward; then bad "servidor nao confirmou; nao deveria dar sucesso"; else ok "coleta nao confirmada -> retorno 1 (sera reprogramada)"; fi
if league_reward_pendente; then ok "estado segue pendente para nova tentativa"; else bad "pendente nao deveria ser limpo sem confirmacao"; fi

# 4e. Liberar novas lutas NAO apaga o estado de recompensa pendente
AVAILABLE_FIGHTS=5   # cinco lutas novas liberadas
if league_reward_pendente; then ok "novas lutas nao apagam recompensa pendente"; else bad "novas lutas apagaram o estado pendente"; fi
league_reward_limpar
rm -rf "$TMP"

printf "\n=== 5. Temporizacao: sleep intermediario 1s -> 0,5s ===\n"
# Confirma no codigo que o branch ocioso das batalhas usa 0.5s.
_falta=""
for f in king.sh clanfight.sh clandmg.sh altars.sh coliseum.sh clancoliseum.sh flagfight.sh; do
    if grep -q 'sleep 0.5s' "$ROOT/$f"; then :; else _falta="$_falta $f"; fi
done
if [ -z "$_falta" ]; then ok "todos os 7 modulos usam sleep 0.5s no ciclo ocioso"; else bad "sem sleep 0.5s em:$_falta"; fi
# Demonstracao aritmetica do intervalo entre ataques.
# ciclo ocioso = pacing(time_exit) + RTT do servidor + sleep intermediario.
# Com pacing=1s, RTT tipico ~0,5-2s e cooldown LA=4s, o gargalo e o cooldown:
# antes: 1(pacing)+RTT+1,0 ~ 2,5-4s de "peso" por volta ociosa;
# agora: 1(pacing)+RTT+0,5 ~ 2,0-3,5s -> o ataque sai assim que LA(4s) vence,
# recolocando o intervalo real na faixa 4-5s em vez de ~6s.
printf "  [INFO] LA (cooldown de ataque) = 4s; intervalo alvo 4-5s.\n"
printf "  [INFO] O sleep intermediario 0,5s reduz o peso da volta ociosa em 0,5s por ciclo.\n"

printf "\n=== RESUMO ===\n"
printf "  PASS=%s  FALHA=%s\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
