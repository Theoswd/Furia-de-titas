# priority.sh - Scheduler orientado por estado + prioridade + horario
# Regra: cronograma de batalha > missao do cla > atividades secundarias.

# BLOQUEIO ABSOLUTO DA BÊNÇÃO.
# Este override e recarregado em runtime depois de todos os modulos.
use_blessing() { return 0; }

priority_state() {
    _p_activity="$1"; _p_page="$2"; _p_status="$3"
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
}

# Janelas de preparacao dos eventos. Sao os minutos em que nenhuma atividade
# secundaria pode ser iniciada. As rotinas dos eventos fazem a espera interna
# ate a abertura e permanecem bloqueando o scheduler ate retornarem.
priority_event_window() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]|13:5[5-9]|20:5[5-9]|09:5[5-9]|15:5[5-9]|21:5[5-9]|12:2[5-9]|16:2[5-9]|22:2[5-9]|10:2[8-9]|14:5[8-9]|10:1[0-4]|16:1[0-4]|09:2[5-9]|21:2[5-9]) return 0 ;;
        *) return 1 ;;
    esac
}

priority_run_event() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]) priority_state cronograma_clan /fights/timetable/ running; [ -n "$CLD" ] && clanfight_start ;;
        13:5[5-9]|20:5[5-9]) priority_state cronograma_altar /fights/timetable/ running; [ -n "$CLD" ] && altars_start ;;
        09:5[5-9]|15:5[5-9]|21:5[5-9]) priority_state cronograma_vale /fights/timetable/ running; undying_start ;;
        12:2[5-9]|16:2[5-9]|22:2[5-9]) priority_state cronograma_rei /fights/timetable/ running; king_start ;;
        10:2[8-9]|14:5[8-9]) priority_state cronograma_coliseu_cla /fights/timetable/ running; [ -n "$CLD" ] && clancoliseum_start ;;
        10:1[0-4]|16:1[0-4]) priority_state cronograma_bandeiras /fights/timetable/ running; flagfight_start ;;
        09:2[5-9]|21:2[5-9]) priority_state cronograma_evento_especial /fights/timetable/ running; [ "${FUNC_auto_events:-y}" = "y" ] && specialEvent ;;
        *) return 1 ;;
    esac
    priority_state cronograma /fights/timetable/ finished
    return 0
}

# Detecta tanto missao concluida (end) quanto missao atualmente em andamento
# (deleteHelp, usado pela pagina para abandonar/encerrar a ajuda). Assim uma
# missao ja tomada continua sendo prioridade mesmo antes de ficar concluida.
priority_clan_type() {
    [ -s "$TMP/CQUEST" ] || return 1
    for _id in 1 2 3 4 5 6 7 8; do
        if grep -q -E "/clan/${CLD}/quest/(end|deleteHelp)/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" 2>/dev/null; then
            case "$_id" in
                1|2) echo liga ;; 3|4) echo arena ;; 5) echo caverna ;;
                6) echo carreira ;; 7) echo elixir ;; 8) echo loja ;;
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
}

priority_run_clan() {
    [ -n "$CLD" ] || return 1

    # Primeiro recolhe e ajuda somente gratuitamente; depois relê a pagina.
    cq_concluir >/dev/null 2>&1
    cq_ajudar >/dev/null 2>&1
    cq_pagina >/dev/null 2>&1 || return 1

    # Se ja existe missao ativa, ela vence qualquer secundaria.
    _type=$(priority_clan_type)
    if [ -n "$_type" ]; then
        priority_execute_clan_type "$_type"
        unset _type
        return $?
    fi

    # Sem missao ativa, toma a primeira disponivel e executa imediatamente a
    # atividade correspondente para nao desperdiçar tentativa.
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
    cq_pagina >/dev/null 2>&1 || return 1
    priority_clan_type >/dev/null 2>&1
}

priority_night_coliseum() {
    case "$(date +%H:%M)" in
        00:3[0-9]|00:[45][0-9]|0[123]:[0-5][0-9]|04:[0-2][0-9]|04:30) return 0 ;;
        *) return 1 ;;
    esac
}

priority_secondary() {
    if [ "${FUNC_masmorra:-y}" = "y" ] && masmorra_na_janela && masmorra_liberada; then
        priority_state masmorra_cla /clandungeon/ running
        clanDungeon
        masmorra_marcar
        return 0
    fi

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

    priority_state carreira /career/ running; career_func
    if priority_event_window || priority_clan_pending; then return 0; fi

    priority_state caverna /cave/ running; cave_routine
    if priority_event_window || priority_clan_pending; then return 0; fi

    priority_state liga /league/ running; league_play 2>/dev/null
    if priority_event_window || priority_clan_pending; then return 0; fi

    priority_state campanha /campaign/ running; campaign_func
    if priority_event_window || priority_clan_pending; then return 0; fi

    priority_state cabana_sabio /sage/ running; check_missions; check_rewards
    if priority_event_window || priority_clan_pending; then return 0; fi

    if [ "${FUNC_auto_events:-y}" = "y" ]; then
        priority_state evento_especial /event/ running
        specialEvent
        if priority_event_window || priority_clan_pending; then return 0; fi
    fi

    # Nao chama clanQuests aqui: priority_run_clan e o unico controlador das
    # missoes do cla, evitando tomar uma missao sem executar sua atividade.

    priority_state laboratorio /lab/ running
    use_elixir 2>/dev/null
    if priority_event_window || priority_clan_pending; then return 0; fi

    priority_state economia /trade/ running; func_trade
    if [ -n "$CLD" ]; then
        priority_state tesouraria_cla "/clan/${CLD}/money/" running
        clan_money
    fi

    return 0
}

twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null
    [ -n "$CLD" ] || clan_id 2>/dev/null
    load_config 2>/dev/null

    # Bloqueios de gasto do agente.
    FUNC_use_blessing=n
    export FUNC_use_blessing
    FUNC_cave_boost=n
    export FUNC_cave_boost
    FUNC_quest_force_gold=n
    export FUNC_quest_force_gold

    while true; do
        # 1) Cronograma de batalha: prioridade absoluta.
        if priority_event_window; then
            priority_run_event
            priority_poll
            continue
        fi

        # 2) Missao do cla.
        if priority_run_clan; then
            cq_concluir >/dev/null 2>&1
            priority_poll
            continue
        fi

        if priority_event_window || priority_clan_pending; then
            continue
        fi

        # 3) Atividades secundarias.
        priority_secondary

        # Reavalia imediatamente depois de cada bloco.
        if priority_event_window || priority_clan_pending; then
            continue
        fi

        messages_info 2>/dev/null
        atualiza_stats 2>/dev/null
        priority_state espera / idle
        priority_poll
    done
}
