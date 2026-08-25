#!/bin/sh
specialEvent() {
    EVENT=""
    event_link=""
    click=""

    fetch_page "/" || return 1

    if grep -q "shb_text" "$TMP/SRC"; then
        event_link=`grep -o -E "<div class='shb_text'><a href='[^']+'" "$TMP/SRC" | sed -E "s/^.*href='([^']+)'.*$/\1/" | sed -n '1p'`
        if [ -n "$event_link" ]; then
            EVENT=`echo "$event_link" | cut -d'/' -f2`
            printf "Current event: %s\n" "$EVENT"
        fi
    fi

    [ -n "$EVENT" ] || return 1

    case $EVENT in
        questrnd)
            fetch_page "$event_link" || return 1
            printf "Event Adventure\n"
            click=`grep -o -E "/questrnd/take/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'`
            [ -n "$click" ] || return 1
            fetch_page "$click"
            printf "Claiming reward\n"
            return 0
            ;;
        fault)
            fetch_page "$event_link" || return 1
            printf "Event fault\n"
            click=`grep -o -E "/fault/attack/\?r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
            [ -n "$click" ] || return 1

            SE_BREAK=$(($(date +%s) + 90))
            _n=0
            while [ "$(date +%s)" -lt "$SE_BREAK" ] && [ "$_n" -lt 60 ]; do
                [ -n "$click" ] || break

                # Evento especial e secundario quando chamado fora da janela
                # oficial; devolve controle imediatamente a prioridade maxima.
                if command -v priority_event_window >/dev/null 2>&1 && priority_event_window; then
                    printf "Event fault: cedendo ao cronograma de batalhas\n"
                    return 2
                fi

                fetch_page "$click" || return 1
                _n=$((_n + 1))
                printf "Attacking monster %s\n" "$_n"
                click=`grep -o -E "/fault/attack/\?r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
                sleep 1
            done
            [ -z "$click" ] && printf "Event fault ok\n"
            unset _n
            ;;
        clandmgfight)
            case `date +%H:%M` in
                09:2[5-9]|21:2[5-9]) clandmgfight_start ;;
                *) return 1 ;;
            esac
            ;;
        marathon)
            fetch_page "/marathon/" || return 1
            printf "Marathon event\n"
            click=`grep -o -E "/marathon/take/\?r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
            [ -n "$click" ] || return 1
            fetch_page "$click"
            printf "Claiming reward\n"
            return 0
            ;;
        *) return 1 ;;
    esac
}
