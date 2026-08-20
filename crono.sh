# shellcheck disable=SC2154
# shellcheck disable=SC2317
func_crono() {
    HOUR=`date +%H | sed 's/^0//'`
    MIN=`date +%M | sed 's/^0//'`
    [ -z "$HOUR" ] && HOUR=0
    [ -z "$MIN" ] && MIN=0
    printf "%s %s\n" "$URL" "`date +%H:%M`"
}

# Lista as funcoes disponiveis (comando "info" no modo interativo).
# CORRECAO: o caminho era "$HOME"/twm/*.sh, resquicio do layout de conta
# unica. No layout multi-contas o codigo fica em $TWMDIR.
info() {
    printf "\n"
    grep -h -o -E '^[[:alnum:]_]+\(\) \{' "$TWMDIR"/*.sh 2>/dev/null \
        | sed 's/() {//' | sort -u
}

# Pausa entre ciclos.
#
# CORRECAO CRITICA (multi-contas): a versao anterior fazia
#     read -r -t "$i" cmd
# para "dormir" $i segundos esperando um comando do usuario. Mas o worker e
# lancado com stdin em /dev/null (play.sh) — o read retorna EOF na hora, a
# pausa nunca acontecia, e o laco "while true; do twm_start; done" do twm.sh
# virava busy-loop de 100% de CPU POR CONTA, com o twm.log crescendo sem
# limite e o start() sendo reexecutado centenas de vezes dentro do mesmo
# minuto (rajada de requisicoes identicas).
#
# Agora: se nao ha terminal, dorme de verdade. Se ha, mantem o modo
# interativo original.
func_cat() {
    func_crono
    [ -f "$TMP/msg_file" ] && cat "$TMP/msg_file"

    _i="${i:-60}"
    case "$_i" in ''|*[!0-9]*) _i=60 ;; esac

    if [ ! -t 0 ]; then
        printf "Sem batalhas agora, aguardando %ss\n" "$_i"
        sleep "$_i"
        return 0
    fi

    while true; do
        printf "Sem batalhas agora, aguardando %ss\n" "$_i"
        printf "Digite um comando (ou 'info' / 'config'):\n"

        read -r -t "$_i" cmd || return 0

        [ -z "$cmd" ] && return 0
        [ "$cmd" = " " ] && return 0

        printf "\n"

        # CORRECAO (seguranca): antes era "$cmd" sem aspas em posicao de
        # comando — qualquer string vinda do stdin era executada. Agora so
        # os comandos previstos rodam.
        case "$cmd" in
            config)      config ;      sleep 1 ; continue ;;
            requer_func) requer_func ; sleep 1 ; continue ;;
            info)        info ;        sleep 1 ; continue ;;
            *) printf "Comando desconhecido: %s\n" "$cmd" ; sleep 1 ; continue ;;
        esac
    done
}

# CORRECAO: "reset" foi removido. Ele executa "stty sane" no TTY que os
# workers herdam do play.sh, o que corrompia o monitor multi-contas na tela
# e enchia o twm.log de sequencias de escape. O "clear" so faz sentido com
# terminal, entao passou a ser condicional.
func_sleep() {
    [ -t 1 ] && clear

    if [ "`date +%d`" -eq 01 ] 2>/dev/null; then
        if [ "${HOUR:-99}" -lt 9 ] 2>/dev/null; then
            coliseum_start
            i=60
            func_cat
            return 0
        fi
    fi

    if [ "${MIN:-0}" -ge 29 ] && [ "${MIN:-0}" -le 30 ] 2>/dev/null; then
        i=15
    else
        i=60
    fi
    func_cat
}

start() {
    load_config

    # CORRECAO (multi-contas): login_logoff() existia em loginlogoff.sh mas
    # NUNCA era chamada por ninguem. Sem isso, quando o cookie expirava a
    # conta seguia batendo na pagina de login para sempre, enquanto o monitor
    # do play.sh continuava mostrando "online" (ele so testa kill -0 do
    # worker). Era o sintoma "a conta aparece online mas parou de jogar".
    if type login_logoff > /dev/null 2>&1; then
        if ! login_logoff; then
            printf "Sessao invalida — pulando este ciclo\n"
            func_crono
            func_sleep
            return 1
        fi
    fi

    pause_missions_weekend
    arena_duel
    career_func
    cave_routine
    func_trade
    campaign_func
    clanDungeon
    clan_statue
    check_missions
    check_rewards

    if [ "${FUNC_auto_events:-y}" = "y" ]; then
        specialEvent
    fi

    if [ "${FUNC_clan_missions:-y}" = "y" ]; then
        clanQuests
    fi

    messages_info
    func_crono
    func_sleep
}
