# priority.sh - Scheduler orientado por estado + prioridade + horario
# Regra: cronograma de batalha > missao do cla > atividades secundarias.

[ -f "$TWMDIR/state.sh" ] && . "$TWMDIR/state.sh"
[ -f "$TWMDIR/action_runner.sh" ] && . "$TWMDIR/action_runner.sh"
[ -f "$TWMDIR/resource_guard.sh" ] && . "$TWMDIR/resource_guard.sh"

# Compatibilidade. O bloqueio definitivo da Bencao fica em blessing.sh,
# carregado por ultimo por run.sh.
use_blessing() { return 3; }

priority_state() {
    _p_activity="$1"; _p_page="$2"; _p_status="$3"; _p_detail="${4:-}"
    {
        printf 'timestamp=%s\n' "$(date +%s)"
        printf 'activity=%s\n' "$_p_activity"
        printf 'page=%s\n' "$_p_page"
        printf 'status=%s\n' "$_p_status"
        [ -n "$_p_detail" ] && printf 'detail=%s\n' "$_p_detail"
    } > "$TMP/priority_state" 2>/dev/null
    command -v runtime_state_write >/dev/null 2>&1 && \
        runtime_state_write "$_p_activity" "$_p_page" "$_p_status" "$_p_detail" 2>/dev/null
    unset _p_activity _p_page _p_status _p_detail
}

priority_poll() {
    _p=${FUNC_priority_poll:-5}
    case "$_p" in ''|*[!0-9]*) _p=5 ;; esac
    sleep "$_p"
}

priority_task_due() {
    _pt_name="$1"; _pt_sec="$2"
    case "$_pt_name" in ''|*[!A-Za-z0-9_-]*) return 1 ;; esac
    case "$_pt_sec" in ''|*[!0-9]*) _pt_sec=300 ;; esac
    _pt_last=0
    [ -r "$TMP/last_${_pt_name}" ] && read -r _pt_last < "$TMP/last_${_pt_name}" || :
    case "$_pt_last" in ''|*[!0-9]*) _pt_last=0 ;; esac
    _pt_now=`date +%s`
    [ $((_pt_now - _pt_last)) -ge "$_pt_sec" ]
    _pt_rc=$?
    unset _pt_name _pt_sec _pt_last _pt_now
    return "$_pt_rc"
}

priority_task_mark() {
    _pt_name="$1"
    case "$_pt_name" in ''|*[!A-Za-z0-9_-]*) return 1 ;; esac
    date +%s > "$TMP/last_${_pt_name}" 2>/dev/null
    unset _pt_name
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

priority_event_slot() {
    _date=`date +%Y%m%d`
    case "$(date +%H:%M)" in
        10:5[5-9]) _slot=1055 ;; 18:5[5-9]) _slot=1855 ;;
        13:5[5-9]) _slot=1355 ;; 20:5[5-9]) _slot=2055 ;;
        09:5[5-9]) _slot=0955 ;; 15:5[5-9]) _slot=1555 ;; 21:5[5-9]) _slot=2155 ;;
        12:2[5-9]) _slot=1225 ;; 16:2[5-9]) _slot=1625 ;; 22:2[5-9]) _slot=2225 ;;
        10:2[8-9]) _slot=1028 ;; 14:5[8-9]) _slot=1458 ;;
        10:1[0-4]) _slot=1010 ;; 16:1[0-4]) _slot=1610 ;;
        09:2[5-9]) _slot=0925 ;; 21:2[5-9]) _slot=2125 ;;
        *) _slot=`date +%H%M` ;;
    esac
    _ev=`priority_event_name`
    printf '%s-%s-%s' "$_date" "$_ev" "$_slot"
    unset _date _slot _ev
}

priority_timetable_refresh() {
    _last=0
    [ -r "$TMP/last_timetable_fetch" ] && read -r _last < "$TMP/last_timetable_fetch" || :
    case "$_last" in ''|*[!0-9]*) _last=0 ;; esac
    _now=`date +%s`
    [ $((_now - _last)) -ge 60 ] || { unset _last _now; return 0; }

    _old_page=""
    [ -r "$TMP/pagina" ] && read -r _old_page < "$TMP/pagina" || :
    if fetch_page "/fights/timetable/" "$TMP/TIMETABLE" 2>/dev/null; then
        printf '%s\n' "$_now" > "$TMP/last_timetable_fetch"
    fi
    [ -n "$_old_page" ] && printf '%s' "$_old_page" > "$TMP/pagina" 2>/dev/null
    unset _last _now _old_page
}

# Guard usado dentro de atividades longas. Missao do cla NAO faz requisicao
# aqui; ela e verificada explicitamente antes de cada atividade secundaria.
priority_guard() {
    priority_event_window && return 1
    command -v event_lock_active >/dev/null 2>&1 && event_lock_active && return 1
    return 0
}

priority_run_event() {
    _ev=`priority_event_name`
    _slot=`priority_event_slot`

    if command -v event_slot_seen >/dev/null 2>&1 && event_slot_seen "$_slot"; then
        priority_state cronograma /fights/timetable/ waiting "janela ja processada: $_slot"
        unset _ev _slot
        return 3
    fi

    if command -v event_retry_allowed >/dev/null 2>&1 && ! event_retry_allowed "$_slot"; then
        _tries=`event_retry_count "$_slot" 2>/dev/null`
        case "$_tries" in ''|*[!0-9]*) _tries=0 ;; esac
        if [ "$_tries" -ge 3 ]; then
            command -v event_slot_mark >/dev/null 2>&1 && event_slot_mark "$_slot"
            priority_state cronograma /fights/timetable/ failed "limite de 3 tentativas atingido: $_slot"
            unset _ev _slot _tries
            return 1
        fi
        priority_state cronograma /fights/timetable/ waiting "retry em cooldown: tentativa $_tries/3"
        unset _ev _slot _tries
        return 4
    fi

    command -v event_lock_start >/dev/null 2>&1 && event_lock_start "$_ev"
    command -v combat_state_write >/dev/null 2>&1 && combat_state_write "$_ev" waiting "" ""

    _rc=1
    case "$(date +%H:%M)" in
        10:5[5-9]|18:5[5-9])
            priority_state cronograma_clan /fights/timetable/ running
            if [ -n "$CLD" ]; then clanfight_start; _rc=$?; else _rc=3; fi ;;
        13:5[5-9]|20:5[5-9])
            priority_state cronograma_altar /fights/timetable/ running
            if [ -n "$CLD" ]; then altars_start; _rc=$?; else _rc=3; fi ;;
        09:5[5-9]|15:5[5-9]|21:5[5-9])
            priority_state cronograma_vale /fights/timetable/ running
            undying_start; _rc=$? ;;
        12:2[5-9]|16:2[5-9]|22:2[5-9])
            priority_state cronograma_rei /fights/timetable/ running
            king_start; _rc=$? ;;
        10:2[8-9]|14:5[8-9])
            priority_state cronograma_coliseu_cla /fights/timetable/ running
            if [ -n "$CLD" ]; then clancoliseum_start; _rc=$?; else _rc=3; fi ;;
        10:1[0-4]|16:1[0-4])
            priority_state cronograma_bandeiras /fights/timetable/ running
            flagfight_start; _rc=$? ;;
        09:2[5-9]|21:2[5-9])
            priority_state cronograma_evento_especial /fights/timetable/ running
            if [ "${FUNC_auto_events:-y}" = "y" ]; then specialEvent; _rc=$?; else _rc=3; fi ;;
        *) _rc=3 ;;
    esac

    command -v combat_state_clear >/dev/null 2>&1 && combat_state_clear

    case "$_rc" in
        0)
            command -v event_lock_finish >/dev/null 2>&1 && event_lock_finish "$_ev" returned
            command -v event_slot_mark >/dev/null 2>&1 && event_slot_mark "$_slot"
            priority_state cronograma /fights/timetable/ returned "modulo confirmou fim normal"
            ;;
        3)
            command -v event_lock_finish >/dev/null 2>&1 && event_lock_finish "$_ev" skipped
            command -v event_slot_mark >/dev/null 2>&1 && event_slot_mark "$_slot"
            priority_state cronograma /fights/timetable/ skipped "evento indisponivel/desabilitado"
            ;;
        *)
            command -v event_lock_finish >/dev/null 2>&1 && event_lock_finish "$_ev" failed
            command -v event_retry_mark >/dev/null 2>&1 && event_retry_mark "$_slot"
            _tries=`event_retry_count "$_slot" 2>/dev/null`
            case "$_tries" in ''|*[!0-9]*) _tries=1 ;; esac
            if [ "$_tries" -ge 3 ]; then
                command -v event_slot_mark >/dev/null 2>&1 && event_slot_mark "$_slot"
                priority_state cronograma /fights/timetable/ failed "rc=$_rc; retries esgotados"
            else
                priority_state cronograma /fights/timetable/ failed "rc=$_rc; tentativa $_tries/3"
            fi
            unset _tries
            ;;
    esac

    _out=$_rc
    unset _ev _slot _rc
    return "$_out"
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

priority_clan_save_type() {
    _pct="$1"
    case "$_pct" in liga|arena|caverna|carreira|elixir|loja) ;; *) return 1 ;; esac
    printf '%s|%s\n' "$_pct" "$(date +%s)" > "$TMP/clan_active_type" 2>/dev/null
    unset _pct
}

priority_clan_saved_type() {
    [ -r "$TMP/clan_active_type" ] || return 1
    IFS='|' read -r _pct _pts < "$TMP/clan_active_type" || return 1
    case "$_pct" in liga|arena|caverna|carreira|elixir|loja) ;;
        *) rm -f "$TMP/clan_active_type"; unset _pct _pts; return 1 ;;
    esac
    case "$_pts" in ''|*[!0-9]*) _pts=0 ;; esac
    _pnow=`date +%s`
    if [ $((_pnow - _pts)) -gt 1800 ]; then
        rm -f "$TMP/clan_active_type" 2>/dev/null
        unset _pct _pts _pnow
        return 1
    fi
    printf '%s' "$_pct"
    unset _pct _pts _pnow
}

priority_clan_clear_type() { rm -f "$TMP/clan_active_type" 2>/dev/null; }

priority_execute_clan_type() {
    PRIORITY_CLAN_ACTIVE=y
    export PRIORITY_CLAN_ACTIVE

    case "$1" in
        liga) priority_state missao_cla_liga "/clan/${CLD}/quest/" running; league_play 2>/dev/null; _rc=$? ;;
        arena) priority_state missao_cla_arena "/clan/${CLD}/quest/" running; arena_duel; _rc=$? ;;
        caverna) priority_state missao_cla_caverna "/clan/${CLD}/quest/" running; cave_routine; _rc=$? ;;
        carreira) priority_state missao_cla_carreira "/clan/${CLD}/quest/" running; career_func; _rc=$? ;;
        elixir) priority_state missao_cla_elixir "/clan/${CLD}/quest/" running; use_elixir; _rc=$? ;;
        loja) priority_state missao_cla_loja "/clan/${CLD}/quest/" running; func_trade; _rc=$? ;;
        *) _rc=1 ;;
    esac

    PRIORITY_CLAN_ACTIVE=n
    export PRIORITY_CLAN_ACTIVE
    return "$_rc"
}

priority_clan_due() {
    _pcs=${FUNC_priority_clan_sec:-30}
    case "$_pcs" in ''|*[!0-9]*) _pcs=30 ;; esac
    priority_task_due clan_scheduler "$_pcs"
    _prc=$?
    unset _pcs
    return "$_prc"
}

priority_run_clan() {
    [ -n "$CLD" ] || return 1

    cq_concluir >/dev/null 2>&1
    _done=$?
    [ "$_done" -eq 0 ] && priority_clan_clear_type

    cq_ajudar >/dev/null 2>&1
    cq_pagina >/dev/null 2>&1 || { priority_task_mark clan_scheduler; unset _done; return 1; }

    _type=`priority_clan_saved_type 2>/dev/null`
    [ -n "$_type" ] || _type=`priority_clan_type 2>/dev/null`

    if [ -n "$_type" ]; then
        priority_execute_clan_type "$_type"
        _rc=$?
        cq_concluir >/dev/null 2>&1 && priority_clan_clear_type
        priority_task_mark clan_scheduler
        unset _type _done
        return "$_rc"
    fi

    for _type in liga arena caverna carreira elixir loja; do
        if cq_tomar "$_type" >/dev/null 2>&1; then
            priority_clan_save_type "$_type"
            priority_execute_clan_type "$_type"
            _rc=$?
            cq_concluir >/dev/null 2>&1 && priority_clan_clear_type
            priority_task_mark clan_scheduler
            unset _type _done
            return "$_rc"
        fi
    done

    priority_task_mark clan_scheduler
    unset _type _done
    return 1
}

# 0 = pode continuar; 1 = evento superior; 2 = missao do cla foi tratada.
priority_before_secondary() {
    priority_guard || return 1
    if priority_clan_due; then
        if priority_run_clan; then
            return 2
        fi
    fi
    priority_guard
}

priority_night_coliseum() {
    case "$(date +%H:%M)" in
        00:3[0-9]|00:[45][0-9]|0[123]:[0-5][0-9]|04:[0-2][0-9]|04:30) return 0 ;;
        *) return 1 ;;
    esac
}

priority_secondary() {
    command -v event_lock_active >/dev/null 2>&1 && event_lock_active && return 0

    # Missoes gerais cedo: antes ficavam depois do Coliseu e podiam passar
    # horas sem serem sequer verificadas.
    if priority_task_due missions 300; then
        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state missoes /quest/ running
        pause_missions_weekend 2>/dev/null
        check_missions
        check_rewards
        priority_task_mark missions
        unset _pbs
    fi

    if [ "${FUNC_masmorra:-y}" = "y" ] && masmorra_na_janela && masmorra_liberada; then
        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state masmorra_cla /clandungeon/ running
        if clanDungeon; then
            masmorra_marcar
            priority_state masmorra_cla /clandungeon/ returned "ataques gratuitos enviados"
        else
            priority_state masmorra_cla /clandungeon/ waiting "nenhum ataque gratuito confirmado"
        fi
        unset _pbs
        priority_guard || return 0
    fi

    if arena_liberada; then
        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state arena /arena/ running
        arena_duel
        _arc=$?
        case "$_arc" in 0|3) arena_marcar ;; esac
        unset _arc _pbs
        priority_guard || return 0
    fi

    # Coliseu noturno: no maximo uma tentativa a cada 5 min e depois volta
    # para o restante das atividades, em vez de monopolizar 00:30-04:30.
    if priority_night_coliseum && priority_task_due coliseum 300; then
        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state coliseu /coliseum/ running
        coliseum_fight
        priority_task_mark coliseum
        unset _pbs
        priority_guard || return 0
    fi

    # Rotina completa no maximo a cada 10 min. Antes era reexecutada a cada
    # poucos segundos quando nao havia evento, gerando carga e rate-limit.
    if priority_task_due routine 600; then
        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }

        priority_state carreira /career/ running; career_func
        priority_guard || { unset _pbs; return 0; }

        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state caverna /cave/ running; cave_routine
        priority_guard || { unset _pbs; return 0; }

        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state liga /league/ running; league_play 2>/dev/null
        priority_guard || { unset _pbs; return 0; }

        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state campanha /campaign/ running; campaign_func
        priority_guard || { unset _pbs; return 0; }

        if [ "${FUNC_auto_events:-y}" = "y" ]; then
            priority_before_secondary; _pbs=$?
            [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
            [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
            priority_state evento_especial /event/ running; specialEvent
            priority_guard || { unset _pbs; return 0; }
        fi

        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state elixir /inv/chest/ running; use_elixir 2>/dev/null
        priority_guard || { unset _pbs; return 0; }

        priority_before_secondary; _pbs=$?
        [ "$_pbs" -eq 2 ] && { unset _pbs; return 0; }
        [ "$_pbs" -ne 0 ] && { unset _pbs; return 0; }
        priority_state troca /trade/exchange running; func_trade

        priority_task_mark routine
        unset _pbs
    fi

    return 0
}

twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null
    load_config 2>/dev/null
    [ -n "$CLD" ] || clan_id 2>/dev/null

    FUNC_use_blessing=n
    FUNC_cave_boost=n
    FUNC_quest_force_gold=n
    PRIORITY_CLAN_ACTIVE=n
    export FUNC_use_blessing FUNC_cave_boost FUNC_quest_force_gold PRIORITY_CLAN_ACTIVE

    while true; do
        priority_timetable_refresh 2>/dev/null

        # Exclusividade real de evento.
        if command -v event_lock_active >/dev/null 2>&1 && event_lock_active; then
            priority_state cronograma /fights/timetable/ running "event_lock ativo"
            priority_poll
            continue
        fi

        if priority_event_window; then
            priority_run_event
            priority_poll
            continue
        fi

        # Missao do cla sempre vem antes do ciclo secundario, com intervalo
        # curto para evitar bombardear o servidor em todas as contas.
        if priority_clan_due; then
            if priority_run_clan; then
                priority_poll
                continue
            fi
        fi

        priority_secondary

        priority_guard || { priority_poll; continue; }

        messages_info 2>/dev/null
        if stats_liberado 2>/dev/null; then atualiza_stats 2>/dev/null; fi
        descansar 2>/dev/null
        priority_state espera / idle
        priority_poll
    done
}
