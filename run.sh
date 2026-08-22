twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null

    if [ ! -s "$TMP/CLD" ]; then
        clan_id
    fi

    # ORDEM DE PRIORIDADE DOS EVENTOS
    # O case original e preservado como fallback de compatibilidade.
    case `date +%H:%M` in
        (10:5[5-9]|18:5[5-9])
            if [ -n "$CLD" ]; then clanfight_start; fi
            start ;;
        (13:5[5-9]|20:5[5-9])
            if [ -n "$CLD" ]; then altars_start; fi
            start ;;
        (09:5[5-9]|15:5[5-9]|21:5[5-9])
            undying_start
            start ;;
        (12:2[5-9]|16:2[5-9]|22:2[5-9])
            king_start
            start ;;
        (10:2[8-9]|14:5[8-9])
            if [ -n "$CLD" ]; then clancoliseum_start; fi
            start ;;
        (00:3[0-9]|00:[45][0-9]|0[123]:[0-5][0-9]|04:[0-2][0-9]|04:30)
            coliseum_fight
            tarefas_livres ;;
        (10:1[0-4]|16:1[0-4])
            flagfight_start ;;
        (09:2[5-9]|21:2[5-9])
            specialEvent
            start ;;
        (00:00|01:00|02:00|03:00|04:3[1-9]|05:00|05:30|06:00|06:30|07:00|07:30|08:00|08:30|09:00|11:00|11:30|12:00|13:00|13:30|14:00|14:30|15:00|15:30|17:00|17:30|18:00|18:30|19:00|19:30|20:00|20:30|22:00|23:00|23:30)
            start ;;
        (*)
            tarefas_livres
            func_sleep
            func_crono ;;
    esac
}

# Reinicia APENAS esta conta.
restart_script() {
    printf "[%s] %s — reiniciando esta conta\n" "$TWM_TAG" "${ACC:-$TWM_USER}"
    exit 0
}

# Scheduler de prioridade carregado por ultimo, substituindo twm_play.
[ -f "$TWMDIR/priority.sh" ] && . "$TWMDIR/priority.sh"
