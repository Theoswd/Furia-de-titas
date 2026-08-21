#!/bin/sh
# panel.sh - Painel do TWM (biblioteca, nao roda sozinho)
#
# Compartilhado pelo play.sh e pelo status.sh. Por padrao e SOMENTE LEITURA:
# desenha o que os workers escreveram em ~/.twm e nao toca em processo nenhum.
#
# O play.sh liga a supervisao com PANEL_SUPERVISE=1, que faz o laco relancar
# worker morto. O status.sh deixa em 0 e por isso pode ser aberto e fechado a
# vontade, sem derrubar conta nenhuma.
#
# Espera receber de quem sourceia: TWMDIR, STATUS_DIR, ACCOUNTS_FILE,
# server_tag(), clean_field() e — so quando PANEL_SUPERVISE=1 — launch_worker().

# ============================================================
#  PAINEL
#  So faz sentido com terminal. Sob systemd (ou qualquer saida
#  redirecionada) seria reimpresso a cada 20s no journal; nesse
#  caso o laco segue supervisionando e relancando, em silencio.
# ============================================================
if [ -t 1 ]; then HAS_TTY=1; else HAS_TTY=0; fi

# Cores
C_RESET='\033[0m';   C_DIM='\033[2m';      C_BOLD='\033[1m'
C_CYAN='\033[1;36m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'
C_RED='\033[1;31m';  C_MAG='\033[1;35m';   C_WHITE='\033[1;37m'
C_GOLD='\033[0;33m'; C_GRAY='\033[0;37m';  C_BLUE='\033[1;34m'

# Emoji ou ASCII.
#
# Muitos terminais (Windows Terminal sem fonte de emoji, consoles antigos)
# desenham quadrados no lugar dos simbolos. Por isso o padrao e ASCII com
# cor, que funciona em qualquer lugar. Para ligar os emoji:
#     TWM_EMOJI=1 ./play.sh
if [ "${TWM_EMOJI:-0}" = "1" ]; then
    I_HP="❤️ "; I_EN="⚡ "; I_LV="⭐ "; I_GO="🪙 "; I_SI="🥈 "
    I_TIT="🎮 "; I_ACT="📋 "; I_EVT="⏰ "; I_ARROW="▸"
    S_ON="🟢"; S_WAIT="🟡"; S_ERR="🔴"; S_OFF="⚫"; S_UNK="⚪"; S_PAUSE="⏸️"
    A_CLANFIGHT="🏆  Torneio do Clã";   A_ALTARES="🔥  Altares dos Deuses"
    A_VALE="🌘  Vale dos Imortais";     A_REI="👑  Rei dos Imortais"
    A_CLANCOL="🏛️  Coliseu do Clã";     A_MASMORRA="🗝️  Masmorra do Clã"
    A_CLANQUEST="📜  Missões do Clã";   A_BANDEIRAS="🚩  Batalha de Bandeiras"
    A_COLISEU="🏟️  Coliseu";            A_ARENA="⚔️  Arena"
    A_CARREIRA="🎖️  Carreira";          A_CAVERNA="⛏️  Caverna"
    A_CAMPANHA="🗺️  Campanha";          A_LIGA="🥇  Liga dos Favoritos"
    A_TROCA="💱  Troca Prata/Ouro";     A_SABIO="🧙  Cabana do Sábio"
    A_EVENTO="🎉  Evento Especial";     A_DESCANSO="💤  Descansando"
    A_NONE="—"
else
    I_HP="HP"; I_EN="Eng"; I_LV="LV"; I_GO="Ouro"; I_SI="PR"
    I_TIT=""; I_ACT=""; I_EVT=""; I_ARROW="->"
    S_ON="[on]"; S_WAIT="[..]"; S_ERR="[off]"; S_OFF="[--]"; S_UNK="[??]"; S_PAUSE="[||]"
    A_CLANFIGHT="Torneio do Clã";   A_ALTARES="Altares dos Deuses"
    A_VALE="Vale dos Imortais";     A_REI="Rei dos Imortais"
    A_CLANCOL="Coliseu do Clã";     A_MASMORRA="Masmorra do Clã"
    A_CLANQUEST="Missões do Clã";   A_BANDEIRAS="Batalha de Bandeiras"
    A_COLISEU="Coliseu";            A_ARENA="Arena"
    A_CARREIRA="Carreira";          A_CAVERNA="Caverna"
    A_CAMPANHA="Campanha";          A_LIGA="Liga dos Favoritos"
    A_TROCA="Troca Prata/Ouro";     A_SABIO="Cabana do Sábio"
    A_EVENTO="Evento Especial";     A_DESCANSO="Descansando"
    A_NONE="-"
fi

LINHA="--------------------------------------------------------------------"

# Agenda de eventos, extraida do case de horarios do run.sh.
# Horarios em America/Bahia (BRT), que e o fuso usado pelos workers.
EVENTOS="0030|Coliseu
0925|Evento especial
0955|Imortais
1010|Batalha de Bandeiras
1028|Coliseu do Cla
1055|Batalha de Clas
1225|Rei dos Imortais
1355|Altares
1458|Coliseu do Cla
1555|Imortais
1610|Batalha de Bandeiras
1625|Rei dos Imortais
1855|Batalha de Clas
2055|Altares
2125|Evento especial
2155|Imortais
2225|Rei dos Imortais"

# Devolve: "Nome  HH:MM BRT  (em Xh Ym)"
proximo_evento() {
    # Agenda oficial do jogo, escrita pelo worker a partir de /fights/.
    # Usada quando tiver menos de 2 horas; caso contrario cai na lista
    # fixa abaixo, que foi conferida contra o jogo e bate com folga de
    # 2 a 5 minutos (janela em que o bot se prepara para entrar).
    _ag="$HOME/.twm/agenda"
    if [ -s "$_ag" ]; then
        _idade=$(( $(date +%s) - $(stat -c %Y "$_ag" 2>/dev/null || echo 0) ))
        if [ "$_idade" -lt 7200 ]; then
            EVENTOS=`cat "$_ag"`
        fi
    fi
    _agora=`TZ=America/Bahia date +%H%M`
    _ai=`printf %s "$_agora" | sed "s/^0*//"`; [ -z "$_ai" ] && _ai=0
    _pn=""; _pt=""
    # IFS so de nova linha: sem isto o "for" divide tambem nos espacos
    # e nomes como "Coliseu do Cla" viram tres iteracoes.
    _oifs=$IFS
    IFS="
"
    for _e in $EVENTOS; do
        _t=${_e%%|*}; _n=${_e#*|}
        _ti=`printf %s "$_t" | sed "s/^0*//"`; [ -z "$_ti" ] && _ti=0
        if [ "$_ti" -gt "$_ai" ]; then _pn=$_n; _pt=$_t; break; fi
    done
    IFS=$_oifs
    # Nenhum restante hoje: o proximo e o primeiro de amanha.
    if [ -z "$_pt" ]; then
        _pe=`printf %s "$EVENTOS" | head -n1`
        _pt=${_pe%%|*}; _pn=${_pe#*|}
        _ti=`printf %s "$_pt" | sed "s/^0*//"`; [ -z "$_ti" ] && _ti=0
        _falta=$(( (24*60) - (_ai/100*60 + _ai%100) + (_ti/100*60 + _ti%100) ))
    else
        _falta=$(( (_ti/100*60 + _ti%100) - (_ai/100*60 + _ai%100) ))
    fi
    _hh=`printf %s "$_pt" | cut -c1-2`; _mm=`printf %s "$_pt" | cut -c3-4`
    if [ "$_falta" -ge 60 ]; then
        printf "%s  %s:%s BRT  (em %dh%02dm)" "$_pn" "$_hh" "$_mm" $((_falta/60)) $((_falta%60))
    else
        printf "%s  %s:%s BRT  (em %dm)" "$_pn" "$_hh" "$_mm" "$_falta"
    fi
}


estado_cor() {
    case "$1" in
        running)                                echo "$C_GREEN" ;;
        paused)                                 echo "$C_CYAN" ;;
        starting|loading|login_retry|restarting) echo "$C_YELLOW" ;;
        dead)                                   echo "$C_RED" ;;
        stopped)                                echo "$C_GRAY" ;;
        *)                                      echo "$C_GRAY" ;;
    esac
}
estado_simbolo() {
    case "$1" in
        running)                                echo "$S_ON" ;;
        paused)                                 echo "$S_PAUSE" ;;
        starting|loading|login_retry|restarting) echo "$S_WAIT" ;;
        dead)                                   echo "$S_ERR" ;;
        stopped)                                echo "$S_OFF" ;;
        *)                                      echo "$S_UNK" ;;
    esac
}

# Nome da aba em que a conta esta agora.
#
# O fetch_page grava o caminho acessado em $TMP/pagina, entao aqui e so
# traduzir. Descanso deixa de ser um rotulo generico: quando a conta volta
# para "/", o painel mostra "Pagina Principal", que e onde ela de fato esta.
aba_de() {
    _p=`cat "$1/pagina" 2>/dev/null`
    case "$_p" in
        ""|"/"|"/?out_gate_confirm=true") echo "Página Principal" ;;
        "/?sign_in=1")    echo "Entrando" ;;
        /fights*)         echo "Agenda de Batalhas" ;;
        /arena*)          echo "Arena" ;;
        /career*)         echo "Carreira" ;;
        /cave*)           echo "Caverna" ;;
        /campaign*)       echo "Campanha" ;;
        /coliseum*)       echo "Coliseu" ;;
        /clancoliseum*)   echo "Coliseu do Clã" ;;
        /clanfight*)      echo "Torneio dos Clãs" ;;
        /clandungeon*|/clandmgfight*) echo "Masmorra do Clã" ;;
        /clan/*quest*)    echo "Missões do Clã" ;;
        /clan/*built*)    echo "Estátua do Clã" ;;
        /clan*)           echo "Clã" ;;
        /altars*)         echo "Altares dos Deuses" ;;
        /undying*)        echo "Vale dos Imortais" ;;
        /king*)           echo "Rei dos Imortais" ;;
        /flagfight*)      echo "Batalha de Bandeiras" ;;
        /league*)         echo "Liga dos Favoritos" ;;
        /trade*)          echo "Troca" ;;
        /effshop*|/lab*)  echo "Aprimoramento" ;;
        /quest*)          echo "Missões" ;;
        /collector*)      echo "Coleções" ;;
        /relic*)          echo "Relíquias" ;;
        /sage*)           echo "Cabana do Sábio" ;;
        /inv*)            echo "Inventário" ;;
        /train*)          echo "Treino" ;;
        /fault*)          echo "Falha" ;;
        /collfight*)      echo "Batalha Coletiva" ;;
        /marathon*)       echo "Maratona" ;;
        /user*)           echo "Meu Herói" ;;
        *)                echo "$_p" ;;
    esac
    unset _p
}

# Relatorio de combate: HP ao vivo e dano recebido.
#
# Os modulos de combate mantem os arquivos HP e old_HP no diretorio da
# conta durante a luta. Comparando os dois sai o dano levado desde a
# ultima acao, sem precisar alterar os sete modulos de batalha.
#
# Devolve uma das formas:
#   "VOCE ESTA MORTO"            HP zerado
#   "-142 de dano recebido"      perdeu vida desde a ultima leitura
#   "+380 recuperado"            curou
#   ""                           fora de combate
combate_de() {
    _d="$1"
    _hp=`cat "$_d/HP" 2>/dev/null | tr -cd '0-9'`
    _old=`cat "$_d/old_HP" 2>/dev/null | tr -cd '0-9'`
    [ -n "$_hp" ] || { echo ""; return; }

    if [ "$_hp" -eq 0 ] 2>/dev/null; then
        echo "VOCÊ ESTÁ MORTO"
        unset _d _hp _old
        return
    fi

    if [ -n "$_old" ] && [ "$_old" -gt 0 ] 2>/dev/null; then
        _dif=$((_hp - _old))
        if [ "$_dif" -lt 0 ]; then
            printf 'HP %s  (%s de dano recebido)' "$_hp" "$_dif"
        elif [ "$_dif" -gt 0 ]; then
            printf 'HP %s  (+%s recuperado)' "$_hp" "$_dif"
        else
            printf 'HP %s' "$_hp"
        fi
    else
        printf 'HP %s' "$_hp"
    fi
    unset _d _hp _old _dif
}

painel_loop() {
while true; do
    [ -t 1 ] && [ "${PANEL_ONCE:-0}" != "1" ] && clear
    agora=$(date +%H:%M:%S)

    n_on=0; n_up=0; n_off=0; idx=0
    LISTA=""; ATIV=""

    while IFS='|' read -r srv user _enc <&3; do
        srv=$(clean_field "$srv")
        user=$(clean_field "$user")
        case "$srv" in ''|\#*|*[!0-9]*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        [ -z "$tag" ] && continue

        acc_id="${tag}_${user}"
        acc_dir="$HOME/.twm/${acc_id}"
        status_file="$STATUS_DIR/${acc_id}.status"
        pid_file="$STATUS_DIR/${acc_id}.pid"
        status=$(cat "$status_file" 2>/dev/null || echo "?")
        pid=$(cat "$pid_file" 2>/dev/null)

        # O PID esta gravado mas o processo sumiu.
        #
        # Supervisionando (play.sh), relanca. Somente leitura (status.sh),
        # apenas mostra "off" — abrir o painel NUNCA pode mexer nos workers,
        # e esse era justamente o defeito: a unica forma de rever o painel
        # era rodar o play.sh, que derrubava as 6 contas que estavam boas.
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            status="dead"
            if [ "${PANEL_SUPERVISE:-0}" = "1" ]; then
                echo "dead" > "$status_file"
                printf "[monitor] relancando worker\n" >> "$acc_dir/twm.log" 2>/dev/null
                launch_worker "$srv" "$user" "" > /dev/null 2>&1
            fi
        fi

        # CORRECAO: tudo que nao fosse "running" entrava em "parada(s)" —
        # inclusive "loading" e "login_retry", que sao contas SUBINDO. Seis
        # contas autenticando viravam "6 parada(s)", uma leitura que nao
        # corresponde ao que esta acontecendo.
        case "$status" in
            running)                                 n_on=$((n_on + 1)) ;;
            starting|loading|login_retry|restarting) n_up=$((n_up + 1)) ;;
            *)                                       n_off=$((n_off + 1)) ;;
        esac
        idx=$((idx + 1))

        nome="$user"; hp="-"; mp="-"; ene="-"; lvl="-"; ouro="-"; prata="-"
        if [ -s "$acc_dir/stats" ]; then
            IFS='|' read -r nome hp mp ene lvl ouro prata _ts < "$acc_dir/stats"
            [ -z "$nome" ] && nome="$user"
        fi

        cor=$(estado_cor "$status")
        sim=$(estado_simbolo "$status")
        LISTA="${LISTA}$(printf "%b%2s %s %b%-18.18s %b%s %-7s %b%s %-6s %b%s %-4s %b%s %-8s %b%s %s%b" \
            "$C_DIM" "$idx" "$C_RESET" \
            "$cor$sim $C_WHITE" "$nome" \
            "$C_RED" "$I_HP" "$hp" \
            "$C_YELLOW" "$I_EN" "$ene" \
            "$C_MAG" "$I_LV" "$lvl" \
            "$C_GOLD" "$I_GO" "$ouro" \
            "$C_GRAY" "$I_SI" "$prata" "$C_RESET")
"
        # Aba atual + relatorio de combate (HP ao vivo, dano, morte)
        _aba=$(aba_de "$acc_dir")
        _cbt=$(combate_de "$acc_dir")
        if [ -n "$_cbt" ]; then
            case "$_cbt" in
                *MORTO*) _cor_c="$C_RED" ;;
                *dano*)  _cor_c="$C_YELLOW" ;;
                *)       _cor_c="$C_GREEN" ;;
            esac
            ATIV="${ATIV}$(printf "    %b%-18.18s %b%s %b%-22.22s %b%s%b" \
                "$C_WHITE" "$nome" "$C_DIM" "$I_ARROW" "$C_CYAN" "$_aba" "$_cor_c" "$_cbt" "$C_RESET")
"
        else
            ATIV="${ATIV}$(printf "    %b%-18.18s %b%s %b%s%b" \
                "$C_WHITE" "$nome" "$C_DIM" "$I_ARROW" "$C_CYAN" "$_aba" "$C_RESET")
"
        fi
    done 3< "$ACCOUNTS_FILE"

    if [ "${PANEL_DRAW:-$HAS_TTY}" = 1 ]; then
        printf "%b%s%b\n" "$C_BLUE" "$LINHA" "$C_RESET"
        printf "  %b%sTWM Multi-contas%b %b· BR%b%*s%b%s%b\n" \
               "$C_CYAN$C_BOLD" "$I_TIT" "$C_RESET" "$C_DIM" "$C_RESET" 26 '' "$C_WHITE" "$agora" "$C_RESET"
        printf "%b%s%b\n" "$C_BLUE" "$LINHA" "$C_RESET"
        printf "%b" "$LISTA"
        printf "%b%s%b\n" "$C_BLUE" "$LINHA" "$C_RESET"
        printf "  %b%sATIVIDADE EM CONJUNTO%b\n" "$C_CYAN$C_BOLD" "$I_ACT" "$C_RESET"
        printf "%b" "$ATIV"
        printf "%b%s%b\n" "$C_BLUE" "$LINHA" "$C_RESET"
        printf "  %b%s %s online%b  %b%s %s subindo%b  %b%s %s parada(s)%b   %b%sProximo: %s%b\n" \
               "$C_GREEN" "$S_ON" "$n_on" "$C_RESET" \
               "$C_YELLOW" "$S_WAIT" "$n_up" "$C_RESET" \
               "$C_RED" "$S_ERR" "$n_off" "$C_RESET" \
               "$C_YELLOW" "$I_EVT" "$(proximo_evento)" "$C_RESET"
        if [ "${PANEL_SUPERVISE:-0}" != "1" ]; then
            printf "  %bsomente leitura — nao interfere nas contas; ctrl+c sai sem parar nada%b\n" \
                   "$C_DIM" "$C_RESET"
        fi
        printf "%b%s%b\n" "$C_BLUE" "$LINHA" "$C_RESET"
    fi

    # CORRECAO: eram 20 chamadas de "sleep 1" a cada volta do painel, ou
    # seja 60 forks por minuto so para nao fazer nada. Um unico sleep tem
    # o mesmo efeito e conta um processo em vez de vinte — o que importa
    # no Android, onde o total de processos filhos e limitado.
    # Uma volta so (status.sh -1): desenha e sai, sem dormir.
    [ "${PANEL_ONCE:-0}" = "1" ] && break

    sleep "${PANEL_INTERVAL:-20}"
done
}
