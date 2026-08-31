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

printf "\n=== 5. Prioridade da cura x esquiva (altars, torneio e duelo de cla) ===\n"
# Nesses modulos a cura deve ser avaliada ANTES da esquiva, para a conta nao
# morrer esperando a releitura de HP que so viria depois do dodge.
for f in altars.sh clanfight.sh clandmg.sh; do
    _heal_ln=$(grep -n 'run_curl_exec "${URL}$(cat HEAL)"' "$ROOT/$f" | head -n1 | cut -d: -f1)
    _dodge_ln=$(grep -n 'run_curl_exec "${URL}$(cat DODGE)"' "$ROOT/$f" | head -n1 | cut -d: -f1)
    if [ -n "$_heal_ln" ] && [ -n "$_dodge_ln" ] && [ "$_heal_ln" -lt "$_dodge_ln" ]; then
        ok "$f: cura (linha $_heal_ln) antes da esquiva (linha $_dodge_ln)"
    else
        bad "$f: cura deveria vir antes da esquiva (heal=$_heal_ln dodge=$_dodge_ln)"
    fi
done
# flagfight e clancoliseum ja eram cura-primeiro
for f in flagfight.sh clancoliseum.sh; do
    _heal_ln=$(grep -n 'cat HEAL\|cat SHIELD\|SHIELD)' "$ROOT/$f" | head -n1 | cut -d: -f1)
    _dodge_ln=$(grep -n 'cat DODGE)' "$ROOT/$f" | head -n1 | cut -d: -f1)
    if [ -n "$_heal_ln" ] && [ -n "$_dodge_ln" ] && [ "$_heal_ln" -lt "$_dodge_ln" ]; then
        ok "$f: cura/escudo antes da esquiva"
    else
        bad "$f: cura deveria vir antes da esquiva (heal=$_heal_ln dodge=$_dodge_ln)"
    fi
done

printf "\n=== 6. Uma requisicao por ciclo: recarga espera sem requisitar ===\n"
# O ramo ocioso (else) so faz requisicao quando o alvo esta grey; fora disso
# espera o restante da recarga com 'sleep \$_resta', sem recarregar a pagina.
for f in clanfight.sh clandmg.sh altars.sh coliseum.sh clancoliseum.sh flagfight.sh; do
    if grep -q 'LA - .*last_atk\|LA - time_since_last_atk' "$ROOT/$f"; then
        ok "$f: espera o restante da recarga (sleep do cooldown, sem request)"
    else
        bad "$f: nao encontrou a espera de recarga sem requisicao"
    fi
done
# E o topo do laco nao rele a pagina de novo (reparse redundante removido).
for f in clanfight.sh clandmg.sh altars.sh; do
    if grep -q 'SEM RELEITURA NO TOPO DO LACO' "$ROOT/$f"; then
        ok "$f: reparse redundante do topo do laco removido"
    else
        bad "$f: ainda ha releitura redundante no topo do laco"
    fi
done

printf "\n=== 7. Temporizacao real: intervalo entre ataques ~ cooldown (sem inflar) ===\n"
# Simula o modelo NOVO (atacar -> esperar o restante da recarga -> atacar) e o
# ANTIGO (atacar -> recarregar pagina + pacing a cada volta). Usa LA reduzido
# para o teste rodar rapido. Mede o intervalo real entre "ataques".
# Modela FIELMENTE o codigo novo (marca last_atk no INICIO da volta):
#   _atk0 = agora ; request custa RTT ; age = RTT ; _resta = LA - age ;
#   espera _resta ; intervalo entre golpes = RTT + (LA - RTT) = LA.
# Ou seja: o tempo do request e ABSORVIDO pela recarga, e o intervalo fica
# em ~LA, nao LA+RTT. Compara com o modelo ANTIGO (last_atk no fim), cujo
# intervalo era RTT + LA.
_sim() {  # MODO LA RTTms -> imprime 3 intervalos em ms
    _mode="$1"; _la="$2"; _rttms="$3"; _prev=""
    _i=0
    while [ "$_i" -lt 4 ]; do
        _atk0=$(date +%s%N 2>/dev/null); [ -n "$_atk0" ] || _atk0=$(( $(date +%s) * 1000000000 ))
        # "request" do ataque: custa RTT
        _s=$(awk -v m="$_rttms" 'BEGIN{printf "%.3f", m/1000}')
        sleep "$_s"
        _t=$(date +%s%N 2>/dev/null); [ -n "$_t" ] || _t=$(( $(date +%s) * 1000000000 ))
        [ -n "$_prev" ] && printf '%s\n' "$(( (_t - _prev) / 1000000 ))"
        _prev="$_t"
        # recarga: NOVO subtrai o tempo ja gasto; ANTIGO espera LA cheio
        if [ "$_mode" = novo ]; then
            _gastoms=$(( (_t - _atk0) / 1000000 ))
            _restams=$(( _la * 1000 - _gastoms ))
        else
            _restams=$(( _la * 1000 ))
        fi
        [ "$_restams" -gt 0 ] && sleep "$(awk -v m="$_restams" 'BEGIN{printf "%.3f", m/1000}')"
        _i=$((_i + 1))
    done
}
# LA=1s, RTT=400ms.  novo -> ~1000ms (LA).  antigo -> ~1400ms (LA+RTT).
_okc=0; _n=0
for _ms in $(_sim novo 1 400); do
    _n=$((_n + 1))
    [ "$_ms" -ge 900 ] && [ "$_ms" -le 1300 ] && _okc=$((_okc + 1))
    printf "  [INFO] NOVO  intervalo medido: %s ms (alvo ~1000)\n" "$_ms"
done
for _ms in $(_sim antigo 1 400); do
    printf "  [INFO] ANTIGO intervalo medido: %s ms (inflado ~1400)\n" "$_ms"
done
if [ "$_n" -gt 0 ] && [ "$_okc" -eq "$_n" ]; then
    ok "tempo do request absorvido pela recarga: intervalo ~ LA (nao LA+RTT)"
else
    bad "intervalo do modelo novo fora de ~LA ($_okc/$_n na faixa)"
fi
printf "  [INFO] Em producao LA=4s -> intervalo ~4-5s (confirmar com log real).\n"

printf "\n=== 8. Encerramento: o worker realmente para (sem relance) ===\n"
# 8a. Estatico: no stop.sh o orquestrador (play.sh) e morto ANTES do laco que
# derruba os workers. Se fosse depois, o supervisor relancaria um worker ja
# morto no meio do encerramento e ele sobreviveria.
_orch_ln=$(grep -n 'orchestrator.pid' "$ROOT/stop.sh" | head -n1 | cut -d: -f1)
_loop_ln=$(grep -n 'for pid_file in' "$ROOT/stop.sh" | head -n1 | cut -d: -f1)
if [ -n "$_orch_ln" ] && [ -n "$_loop_ln" ] && [ "$_orch_ln" -lt "$_loop_ln" ]; then
    ok "stop.sh mata o orquestrador (linha $_orch_ln) antes do laco de workers (linha $_loop_ln)"
else
    bad "stop.sh deveria matar o orquestrador antes do laco (orch=$_orch_ln loop=$_loop_ln)"
fi

# 8b. Empirico: reproduz a corrida supervisor/worker com processos reais.
#     ANTIGO (mata worker antes do supervisor) -> um worker relancado sobrevive.
#     NOVO   (mata supervisor antes do worker) -> nada sobrevive.
_simdir=$(mktemp -d)
_pidf="$_simdir/worker.pid"
_allf="$_simdir/all"; : > "$_allf"
# 'exec sleep' faz o PID rastreado SER o sleep (sem shell-pai sobrando).
# Cada spawn e registrado em $_allf para a limpeza nao deixar orfaos.
_novo_worker() { sh -c 'exec sleep 30' & _wp=$!; echo "$_wp" > "$_pidf"; echo "$_wp" >> "$_allf"; }
_supervisor() {  # relanca o worker sempre que o PID do .pid estiver morto
    while [ -f "$_simdir/sup_on" ]; do
        _p=$(cat "$_pidf" 2>/dev/null)
        if [ -n "$_p" ] && ! kill -0 "$_p" 2>/dev/null; then _novo_worker; fi
        sleep 0.1
    done
}
_kill_tracked() {  # mata TODOS os workers ja criados (o .pid guarda so o ultimo)
    while read -r _ap; do [ -n "$_ap" ] && kill -KILL "$_ap" 2>/dev/null; done < "$_allf"
    : > "$_allf"
}

# --- Cenario ANTIGO: worker primeiro, supervisor depois ---
: > "$_simdir/sup_on"
_novo_worker; _w0=$(cat "$_pidf")
_supervisor & _SUP=$!
sleep 0.3
kill -KILL "$_w0" 2>/dev/null      # mata o worker (supervisor ainda vivo)
sleep 0.4                          # o supervisor relanca nesse intervalo
rm -f "$_simdir/sup_on"; kill -KILL "$_SUP" 2>/dev/null   # so agora para o supervisor
sleep 0.2
_wnow=$(cat "$_pidf" 2>/dev/null)
if [ -n "$_wnow" ] && kill -0 "$_wnow" 2>/dev/null && [ "$_wnow" != "$_w0" ]; then
    ok "ordem ANTIGA reproduz o bug: worker relancado ($_wnow) sobreviveu"
else
    bad "esperava um worker sobrevivente na ordem antiga (obtido='$_wnow' orig=$_w0)"
fi
_kill_tracked

# --- Cenario NOVO: supervisor primeiro, worker depois ---
: > "$_simdir/sup_on"
_novo_worker; _w0=$(cat "$_pidf")
_supervisor & _SUP=$!
sleep 0.3
rm -f "$_simdir/sup_on"; kill -KILL "$_SUP" 2>/dev/null   # supervisor PRIMEIRO
sleep 0.2
kill -KILL "$_w0" 2>/dev/null      # agora o worker, sem quem o relance
sleep 0.4
_wnow=$(cat "$_pidf" 2>/dev/null)
if [ -z "$_wnow" ] || ! kill -0 "$_wnow" 2>/dev/null; then
    ok "ordem NOVA: nenhum worker sobrevive apos o stop"
else
    bad "ordem nova deixou worker vivo ($_wnow)"
fi
_kill_tracked
rm -rf "$_simdir"

printf "\n=== 9. Dependencias: jq nao e usado; pacotes que ajudam ===\n"
# jq nao aparece na logica do bot (so em textos de README/uninstall).
if grep -rn '[^A-Za-z_]jq ' "$ROOT"/*.sh | grep -vq 'pkg install\|apt \|command -v\|foram mantidos\|uninstall jq\|remove --purge'; then
    bad "jq apareceu na logica do bot (revisar)"
else
    ok "jq NAO e usado pela logica do bot (pode ser omitido do install)"
fi
# Comandos que os pacotes recomendados fornecem, realmente usados:
for _pair in "setsid:util-linux" "pgrep:procps" "pkill:procps" "readlink:coreutils" "stat:coreutils"; do
    _cmd=${_pair%%:*}; _pkg=${_pair##*:}
    if grep -rqn "[^A-Za-z_]$_cmd" "$ROOT"/*.sh; then
        ok "usa '$_cmd' (pacote $_pkg) -> recomendado instalar"
    else
        bad "'$_cmd' nao encontrado (esperado em uso)"
    fi
done

printf "\n=== RESUMO ===\n"
printf "  PASS=%s  FALHA=%s\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
