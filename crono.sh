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

# Janelas fixas da Masmorra do Cla.
# A propria pagina informa: "10 acessos gratis a cada 8 horas a partir
# das 10:00" — ou seja 02:00, 10:00 e 18:00. Nao ha o que calcular.
# Tarefas que NAO dependem da agenda de eventos.
#
# A arena deve sair a cada 30 minutos, mas o start() so era chamado
# nos minutos da agenda — que tem vaos de 60 a 120 minutos, e nenhum
# durante as 4 horas do Coliseu. Medido em producao: a arena saia a
# cada ~52 minutos, e contas recem-cadastradas ficavam com 1 unica
# execucao enquanto as antigas tinham 9.
#
# Isto roda a cada volta do laco principal (~1 min). Cada atividade
# tem o proprio temporizador, entao nada executa fora de hora.
#
# Nao e chamado durante os cinco eventos de prioridade: enquanto a
# conta esta aplicada num deles, nada mais deve competir. Assim que
# o evento termina, o start() roda o checklist do cla e as demais
# atividades normalmente.
tarefas_livres() {
    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi
}

masmorra_na_janela() {
    _h=`date +%H`
    case "$_h" in
        02|10|18) return 0 ;;
        *)        return 1 ;;
    esac
}

# Arena a cada 30 minutos, controlada por marcador em disco para
# sobreviver a reinicios do worker.
arena_liberada() {
    _m=${FUNC_arena_min:-30}
    case "$_m" in ''|*[!0-9]*) _m=30 ;; esac
    _ultimo=`cat "$TMP/last_arena" 2>/dev/null`
    case "$_ultimo" in ''|*[!0-9]*) _ultimo=0 ;; esac
    _agora=`date +%s`
    [ $((_agora - _ultimo)) -ge $((_m * 60)) ]
}
arena_marcar() { date +%s > "$TMP/last_arena" 2>/dev/null; }

# Volta para a pagina inicial. As contas devem descansar ali entre os
# ciclos, e nao numa pagina de combate ou de evento — o jogo mantem o
# personagem "em batalha" e a navegacao seguinte cai em "Fuja da batalha".
descansar() {
    fetch_page "/?out_gate_confirm=true" "$TMP/REST" 2>/dev/null
    fetch_page "/" "$TMP/REST" 2>/dev/null
}

start() {
    load_config

    if type login_logoff > /dev/null 2>&1; then
        if ! login_logoff; then
            printf "Sessao invalida — pulando este ciclo\n"
            func_crono
            func_sleep
            return 1
        fi
    fi

    pause_missions_weekend
    clan_id 2>/dev/null

    # Lider do cla: mantem a estatua ativa (bonus de ouro e de prata).
    clan_statue

    # Missoes do cla vem antes de tudo: recolhe as concluidas, apoia as
    # dos companheiros e forca com ouro as que estao paradas.
    if [ -n "$CLD" ]; then
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
    fi

    # Atividades. Cada uma verifica antes se ha missao do cla que ela
    # completa; havendo, toma a missao para o progresso contar.
    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        arena_marcar
    fi

    # Agenda oficial do jogo, para o painel
    atualiza_agenda 2>/dev/null

    cq_antes carreira 2>/dev/null
    career_func

    cq_antes caverna 2>/dev/null
    cave_routine

    cq_antes liga 2>/dev/null
    league_play 2>/dev/null

    # Batalhas sempre com elixir e bencao
    cq_antes elixir 2>/dev/null
    use_elixir
    use_blessing 2>/dev/null

    campaign_func

    if masmorra_na_janela; then
        clanDungeon
    fi

    func_trade

    # Cabana do Sabio: missoes, colecoes e reliquias
    check_missions
    check_rewards

    if [ "${FUNC_auto_events:-y}" = "y" ]; then
        specialEvent
    fi

    if [ "${FUNC_clan_missions:-y}" = "y" ]; then
        clanQuests
    fi

    messages_info
    descansar
    func_crono
    func_sleep
}
