# priority.sh - Scheduler orientado por estado + prioridade + horario
# Regra: cronograma de batalha > missao do cla > atividades secundarias.

# Carrega os modulos V2 somente quando este scheduler entra em runtime.
[ -f "$TWMDIR/state.sh" ] && . "$TWMDIR/state.sh"
[ -f "$TWMDIR/action_runner.sh" ] && . "$TWMDIR/action_runner.sh"
[ -f "$TWMDIR/resource_guard.sh" ] && . "$TWMDIR/resource_guard.sh"

# BLOQUEIO ABSOLUTO DA BENCAO.
use_blessing() { return 0; }

priority_state() {
    _p_activity="$1"; _p_page="$2"; _p_status="$3"
    {
        printf 'timestamp=%s\n' "$(date +%s)"
        printf 'activity=%s\n' "$_p_activity"
        printf 'page=%s\n' "$_p_page"
        printf 'status=%s\n' "$_p_status"
    } > "$TMP/priority_state" 2>/dev/null
    command -v runtime_state_write >/dev/null 2>&1 && runtime_state_write "$_p_activity" "$_p_page" "$_p_status" 2>/dev/null
    unset _p_activity _p_page _p_status
}

priority_poll() {
    _p=${FUNC_priority_poll:-5}
    case "$_p" in ''|*[!0-9]*) _p=5 ;; esac
    sleep "$_p"
}

priority_event_window() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]|13:5[5-9]|20:5[5-9]|09:5[5-9]|15:5[5-9]|21:5[5-9]|12:2[5-9]|16:2[5-9]|22:2[5-9]|10:2[8-9]|14:5[8-9]|10:1[0-4]|16:1[0-4]|09:2[5-9]|21:2[5-9]) return 0 ;;
        *) return 1 ;;
    esac
}

priority_event_name() {
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]) echo clanfight ;;
        13:5[5-9]|20:5[5-9]) echo altars ;;
        09:5[5-9]|15:5[5-9]|21:5[5-9]) echo undying ;;
        12:2[5-9]|16:2[5-9]|22:2[5-9]) echo king ;;
        10:2[8-9]|14:5[8-9]) echo clancoliseum ;;
        10:1[0-4]|16:1[0-4]) echo flagfight ;;
        09:2[5-9]|21:2[5-9]) echo specialevent ;;
        *) echo cronograma ;;
    esac
}

# Guard usado pelas atividades sequenciais. Uma atividade secundaria deve
# devolver o controle assim que surgir evento/lock ou missao de cla pendente.
priority_guard() {
    priority_event_window && return 1
    command -v event_lock_active >/dev/null 2>&1 && event_lock_active && return 1
    priority_clan_pending && return 1
    return 0
}

priority_run_event() {
    _ev=`priority_event_name`
    command -v event_lock_start >/dev/null 2>&1 && event_lock_start "$_ev"
    command -v combat_state_write >/dev/null 2>&1 && combat_state_write "$_ev" waiting "" ""

    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9]) priority_state cronograma_clan /fights/timetable/ running; [ -n "$CLD" ] && clanfight_start ;;
        13:5[5-9]|20:5[5-9]) priority_state cronograma_altar /fights/timetable/ running; [ -n "$CLD" ] && altars_start ;;
        09:5[5-9]|15:5[5-9]|21:5[5-9]) priority_state cronograma_vale /fights/timetable/ running; undying_start ;;
        12:2[5-9]|16:2[5-9]|22:2[5-9]) priority_state cronograma_rei /fights/timetable/ running; king_start ;;
        10:2[8-9]|14:5[8-9]) priority_state cronograma_coliseu_cla /fights/timetable/ running; [ -n "$CLD" ] && clancoliseum_start ;;
        10:1[0-4]|16:1[0-4]) priority_state cronograma_bandeiras /fights/timetable/ running; flagfight_start ;;
        09:2[5-9]|21:2[5-9]) priority_state cronograma_evento_especial /fights/timetable/ running; [ "${FUNC_auto_events:-y}" = "y" ] && specialEvent ;;
        *) command -v event_lock_finish >/dev/null 2>&1 && event_lock_finish "$_ev" skipped; unset _ev; return 1 ;;
    esac

    command -v combat_state_clear >/dev/null 2>&1 && combat_state_clear
    command -v event_lock_finish >/dev/null 2>&1 && event_lock_finish "$_ev" finished
    priority_state cronograma /fights/timetable/ finished
    unset _ev
    return 0
}

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

    cq_concluir >/dev/null 2>&1
    cq_ajudar >/dev/null 2>&1
    cq_pagina >/dev/null 2>&1 || return 1

    _type=$(priority_clan_type)
    if [ -n "$_type" ]; then
        priority_execute_clan_type "$_type"
        unset _type
        return $?
    fi

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
    command -v event_lock_active >/dev/null 2>&1 && event_lock_active && return 0

    if [ "${FUNC_masmorra:-y}" = "y" ] && masmorra_na_janela && masmorra_liberada; then
        priority_state masmorra_cla /clandungeon/ running
        if clanDungeon; then
            masmorra_marcar
        else
            priority_state masmorra_cla /clandungeon/ waiting
        fi
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
    priority_guard || return 0

    priority_state caverna /cave/ running; cave_routine
    priority_guard || return 0

    priority_state liga /league/ running; league_play 2>/dev/null
    priority_guard || return 0

    priority_state campanha /campaign/ running; campaign_func
    priority_guard || return 0

    priority_state cabana_sabio /sage/ running; check_missions; check_rewards
    priority_guard || return 0

    if [ "${FUNC_auto_events:-y}" = "y" ]; then
        priority_state evento_especial /event/ running
        specialEvent
        priority_guard || return 0
    fi

    priority_state laboratorio /lab/ running
    use_elixir 2>/dev/null
    priority_guard || return 0

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

    # Camada de seguranca runtime. Mesmo que config antigo tenha y, o agente
    # de prioridade nunca permite estes gastos automaticos.
    FUNC_use_blessing=n
    export FUNC_use_blessing
    FUNC_cave_boost=n
    export FUNC_cave_boost
    FUNC_quest_force_gold=n
    export FUNC_quest_force_gold

    while true; do
        if command -v event_lock_active >/dev/null 2>&1 && event_lock_active; then
            priority_state cronograma /fights/timetable/ running
        fi

        if priority_event_window; then
            priority_run_event
            priority_poll
            continue
        fi

        if priority_run_clan; then
            cq_concluir >/dev/null 2>&1
            priority_poll
            continue
        fi

        if ! priority_guard; then
            priority_poll
            continue
        fi

        priority_secondary

        if ! priority_guard; then
            continue
        fi

        messages_info 2>/dev/null
        atualiza_stats 2>/dev/null
        descansar 2>/dev/null
        priority_state espera / idle
        priority_poll
    done
}
