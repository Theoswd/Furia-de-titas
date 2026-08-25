# shellcheck disable=SC2154
# shellcheck disable=SC2317
func_crono() {
    HOUR=`date +%H | sed 's/^0//'`
    MIN=`date +%M | sed 's/^0//'`
    [ -z "$HOUR" ] && HOUR=0
    [ -z "$MIN" ] && MIN=0
    printf "%s %s\n" "$URL" "`date +%H:%M`"
}

info() {
    printf "\n"
    grep -h -o -E '^[[:alnum:]_]+\(\) \{' "$TWMDIR"/*.sh 2>/dev/null \
        | sed 's/() {//' | sort -u
}

func_cat() {
    func_crono
    [ -f "$TMP/msg_file" ] && cat "$TMP/msg_file"

    _i="${i:-60}"
    case "$_i" in ''|*[!0-9]*) _i=60 ;; esac
    printf %s "/" > "${TMP}/pagina" 2>/dev/null

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

        case "$cmd" in
            config)      config ;      sleep 1 ; continue ;;
            requer_func) requer_func ; sleep 1 ; continue ;;
            info)        info ;        sleep 1 ; continue ;;
            *) printf "Comando desconhecido: %s\n" "$cmd" ; sleep 1 ; continue ;;
        esac
    done
}

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

cq_liberado() {
    _m=${FUNC_cq_min:-15}
    case "$_m" in ''|*[!0-9]*) _m=15 ;; esac
    _u=`cat "$TMP/last_cq" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}
cq_marcar() { date +%s > "$TMP/last_cq" 2>/dev/null; }

stats_liberado() {
    _m=${FUNC_stats_min:-3}
    case "$_m" in ''|*[!0-9]*) _m=3 ;; esac
    _u=`cat "$TMP/last_stats" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_m * 60)) ]
}

atualiza_stats() {
    _aba_ant=`cat "${TMP}/pagina" 2>/dev/null`
    _pg=`run_curl "${URL}/user" 2>/dev/null`
    [ -n "$_pg" ] || return 1
    is_logged_in "$_pg" || return 1
    _a=`extract_username "$_pg"`
    [ -n "$_a" ] && ACC="$_a"
    parse_status "$_pg"
    messages_info
    date +%s > "$TMP/last_stats" 2>/dev/null
    printf %s "$_aba_ant" > "${TMP}/pagina" 2>/dev/null
    unset _pg _a _aba_ant
}

masmorra_liberada() {
    _u=`cat "$TMP/last_masmorra" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge 25200 ]
}
masmorra_marcar() { date +%s > "$TMP/last_masmorra" 2>/dev/null; }

arena_liberada() {
    _m=${FUNC_arena_min:-30}
    case "$_m" in ''|*[!0-9]*) _m=30 ;; esac
    _ultimo=`cat "$TMP/last_arena" 2>/dev/null`
    case "$_ultimo" in ''|*[!0-9]*) _ultimo=0 ;; esac
    _agora=`date +%s`
    [ $((_agora - _ultimo)) -ge $((_m * 60)) ]
}
arena_marcar() { date +%s > "$TMP/last_arena" 2>/dev/null; }

masmorra_na_janela() {
    _h=`date +%H`
    case "$_h" in
        02|10|18) return 0 ;;
        *)        return 1 ;;
    esac
}

tarefas_livres() {
    [ -n "$CLD" ] || clan_id 2>/dev/null

    if stats_liberado; then
        atualiza_stats 2>/dev/null
    fi

    if [ -n "$CLD" ] && cq_liberado; then
        printf "Checklist do cla\n"
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
        cq_marcar
    fi

    if masmorra_na_janela && [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then
            masmorra_marcar
        fi
    fi

    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        _arc=$?
        case "$_arc" in 0|3) arena_marcar ;; esac
        unset _arc
    fi
}

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

    clan_statue

    if [ -n "$CLD" ]; then
        cq_concluir    2>/dev/null
        cq_ajudar      2>/dev/null
        cq_forcar_ouro 2>/dev/null
    fi

    if arena_liberada; then
        cq_antes arena 2>/dev/null
        arena_duel
        _arc=$?
        case "$_arc" in 0|3) arena_marcar ;; esac
        unset _arc
    fi

    atualiza_agenda 2>/dev/null

    cq_antes carreira 2>/dev/null
    career_func

    cq_antes caverna 2>/dev/null
    cave_routine

    cq_antes liga 2>/dev/null
    league_play 2>/dev/null

    # Elixir continua permitido. Bencao foi removida deste fluxo; o modulo
    # blessing.sh ainda bloqueia o endpoint no HTTP como segunda camada.
    cq_antes elixir 2>/dev/null
    use_elixir

    campaign_func

    if masmorra_na_janela && [ -n "$CLD" ] && masmorra_liberada; then
        if clanDungeon; then
            masmorra_marcar
        fi
    fi

    cq_antes loja 2>/dev/null
    func_trade

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
