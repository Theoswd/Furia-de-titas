# priority.sh - Scheduler orientado por estado + prioridade + horario
# Regras: cronograma de batalha > missoes do cla > atividades secundarias.
# Este arquivo e carregado por run.sh depois das funcoes originais.

priority_state() {
    _p_activity="$1"
    _p_page="$2"
    _p_status="$3"
    {
        printf 'timestamp=%s\n' "$(date +%s)"
        printf 'activity=%s\n' "$_p_activity"
        printf 'page=%s\n' "$_p_page"
        printf 'status=%s\n' "$_p_status"
    } > "$TMP/priority_state" 2>/dev/null
    unset _p_activity _p_page _p_status
}

priority_poll() {
    _p=${FUNC_priority_poll:-5}
    case "$_p" in ''|*[!0-9]*) _p=5 ;; esac
    sleep "$_p"
    unset _p
}

# Cronograma: a atividade permanece isolada durante a janela/evento.
priority_event_window() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]|13:5[5-9]|20:5[5-9]|09:5[5-9]|15:5[5-9]|21:5[5-9]|12:2[5-9]|16:2[5-9]|22:2[5-9]|10:2[8-9]|14:5[8-9]|10:1[0-4]|16:1[0-4]|09:2[5-9]|21:2[5-9]) return 0 ;;
        *) return 1 ;;
    esac
}

priority_run_event() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9])
            priority_state cronograma_clan /fights/timetable/ running
            [ -n "$CLD" ] && clanfight_start
            ;;
        13:5[5-9]|20:5[5-9])
            priority_state cronograma_altar /fights/timetable/ running
            [ -n "$CLD" ] && altars_start
            ;;
        09:5[5-9]|15:5[5-9]|21:5[5-9])
            priority_state cronograma_vale /fights/timetable/ running
            undying_start
            ;;
        12:2[5-9]|16:2[5-9]|22:2[5-9])
            priority_state cronograma_rei /fights/timetable/ running
            king_start
            ;;
        10:2[8-9]|14:5[8-9])
            priority_state cronograma_coliseu_cla /fights/timetable/ running
            [ -n "$CLD" ] && clancoliseum_start
            ;;
        10:1[0-4]|16:1[0-4])
            priority_state cronograma_bandeiras /fights/timetable/ running
            flagfight_start
            ;;
        09:2[5-9]|21:2[5-9])
            priority_state cronograma_evento_especial /fights/timetable/ running
            [ "${FUNC_auto_events:-y}" = "y" ] && specialEvent
            ;;
        *) return 1 ;;
    esac
    priority_state cronograma /fights/timetable/ finished
    return 0
}

# Retorna o tipo de uma missao que ja esta ativa/concluivel.
priority_clan_type() {
    [ -s "$TMP/CQUEST" ] || return 1
    for _id in 1 2 3 4 5 6 7 8; do
        if grep -q -E "/clan/${CLD}/quest/end/${_id}/[?]r=[0-9]+" "$TMP/CQUEST" 2>/dev/null; then
            case "$_id" in
                1|2) echo liga ;;
                3|4) echo arena ;;
                5) echo caverna ;;
                6) echo carreira ;;
                7) echo elixir ;;
                8) echo loja ;;
            esac
            return 0
        fi
    done
    return 1
}

priority_execute_clan_type() {
    case "$1" in
        liga) priority_state missao_cla_liga "/clan/${CLD}/quest/" running; league_play 2>/dev/null ;;
        arena) priority_state missao_cla_arena "/clan/${CLD}/quest/" running; arena_duel ;;
        caverna) priority_state missao_cla_caverna "/clan/${CLD}/quest/" running; cave_routine ;;
        carreira) priority_state missao_cla_carreira "/clan/${CLD}/quest/" running; career_func ;;
        elixir) priority_state missao_cla_elixir "/clan/${CLD}/quest/" running; use_elixir ;;
        loja) priority_state missao_cla_loja "/clan/${CLD}/quest/" running; func_trade ;;
        *) return 1 ;;
    esac
    return 0
}

# Missao do cla e sempre reavaliada antes de qualquer atividade secundaria.
priority_run_clan() {
    [ -n "$CLD" ] || return 1
    cq_concluir >/dev/null 2>&1
    cq_ajudar >/dev/null 2>&1
    cq_pagina >/dev/null 2>&1 || return 1

    _type=$(priority_clan_type)
    if [ -n "$_type" ]; then
        priority_execute_clan_type "$_type"
        unset _type
        return $?
    fi

    # Se nao houver missao ativa, toma uma disponivel e executa somente a
    # atividade correspondente. Nenhuma tarefa menor entra antes disso.
    for _type in liga arena caverna carreira elixir loja; do
        if cq_tomar "$_type" >/dev/null 2>&1; then
            priority_execute_clan_type "$_type"
            unset _type
            return $?
        fi
    done
    unset _type
    return 1
}

priority_clan_pending() {
    [ -n "$CLD" ] || return 1
    cq_concluir >/dev/null 2>&1
    cq_ajudar >/dev/null 2>&1
    cq_pagina >/dev/null 2>&1 || return 1
    priority_clan_type >/dev/null 2>&1
}

priority_night_coliseum() {
    case "$(date +%H:%M)" in
        00:3[0-9]|00:[45][0-9]|0[123]:[0-5][0-9]|04:[0-2][0-9]|04:30) return 0 ;;
        *) return 1 ;;
    esac
}

# A regra economica da especificacao: nenhuma aceleracao de ouro comum.
# A Caverna usa apenas prata quando a missao do cla exige/beneficia a acao.
priority_secondary() {
    # Masmorra: somente ataques gratuitos, nas janelas de 8h.
    if [ "${FUNC_masmorra:-y}" = "y" ] && masmorra_na_janela && masmorra_liberada; then
        priority_state masmorra_cla /clandungeon/ running
        clanDungeon
        masmorra_marcar
        return 0
    fi

    # Coliseu comum somente na janela definida e nunca acima do cronograma.
    if priority_night_coliseum; then
        priority_state coliseu /coliseum/ running
        coliseum_fight
        return 0
    fi

    if arena_liberada; then
        priority_state arena /arena/ running
        arena_duel
        arena_marcar
        return 0
    fi

    priority_state carreira /career/ running
    career_func

    priority_state caverna /cave/ running
    cave_routine

    priority_state cabana_sabio /sage/ running
    check_missions
    check_rewards

    priority_state campanha /campaign/ running
    campaign_func

    priority_state missoes_gerais /quest/ running
    check_missions
    check_rewards

    priority_state laboratorio /lab/ running
    use_elixir 2>/dev/null
    use_blessing 2>/dev/null

    priority_state economia /trade/ running
    func_trade

    [ -n "$CLD" ] && {
        priority_state tesouraria_cla "/clan/${CLD}/money/" running
        clan_money
    }
    return 0
}

twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null
    [ -n "$CLD" ] || clan_id 2>/dev/null
    load_config 2>/dev/null

    # Desabilita boost de ouro da Caverna. Aceleracao fica restrita a prata
    # e somente quando a atividade estiver ligada a uma missao do cla.
    FUNC_cave_boost=n

    while true; do
        # PRIORIDADE 1: cronograma de batalhas.
        if priority_event_window; then
            priority_run_event
            priority_poll
            continue
        fi

        # PRIORIDADE 2: missao do cla. Conclui, ajuda sem ouro e executa.
        if priority_run_clan; then
            cq_concluir >/dev/null 2>&1
            priority_poll
            continue
        fi

        # Nunca inicia tarefa menor se uma batalha acabou de ficar disponivel.
        if priority_event_window; then continue; fi
        if priority_clan_pending; then continue; fi

        # PRIORIDADE 3+ e somente depois das duas verificacoes acima.
        priority_secondary

        # Recalcula imediatamente; nao segue uma lista fixa cegamente.
        if priority_event_window; then continue; fi
        if priority_clan_pending; then continue; fi
        messages_info 2>/dev/null
        atualiza_stats 2>/dev/null
        priority_state espera / idle
        priority_poll
    done
}
