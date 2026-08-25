check_missions() {
    printf "Checking Missions\n"

    fetch_page "/quest/" || return 1

    for i in 1 2; do
        click=`grep -o -E "/quest/openChest/$i/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        if [ -n "$click" ]; then
            if fetch_page "$click"; then
                printf "Chest %s: acao enviada\n" "$i"
            fi
        fi
    done

    _collect="${COLLECT_REWARDS_RUNTIME:-${FUNC_collect_mission_rewards:-n}}"
    if [ "$_collect" = "n" ]; then
        unset _collect
        return 0
    fi
    unset _collect

    i=0
    while [ "$i" -le 16 ]; do
        click=`grep -o -E "/quest/end/${i}[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        if [ -n "$click" ]; then
            if fetch_page "$click"; then
                printf "Mission %s: coleta enviada\n" "$i"
            fi
        fi
        i=$((i + 1))
    done

    fetch_page "/collector/" || return 1
    click=`grep -o -E "/collector/reward/element/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
    if [ -n "$click" ]; then
        fetch_page "$click" && printf "Collection: coleta enviada\n"
    fi

    printf "Missions checked\n"
}

check_rewards() {
    [ "${FUNC_check_rewards:-n}" = "n" ] && return 0

    fetch_page "/relic/reward/" || return 1

    i=0
    while [ "$i" -le 11 ]; do
        click=`grep -o -E "/relic/reward/${i}/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        if [ -n "$click" ]; then
            fetch_page "$click" && printf "Relic %s: coleta enviada\n" "$i"
        fi
        i=$((i + 1))
    done
}

apply_event() {
    event_path="${1:-}"
    [ -n "$event_path" ] || {
        printf "apply_event: evento vazio ignorado\n"
        return 1
    }

    case "$event_path" in
        *[!A-Za-z0-9_-]*) printf "apply_event: evento invalido: %s\n" "$event_path"; return 1 ;;
    esac

    fetch_page "/${event_path}/" || return 1
    APPLY=`grep -o -E "/${event_path}/enter(Game|Fight)/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
    [ -n "$APPLY" ] || return 1

    fetch_page "$APPLY" || return 1
    printf "Event %s: entrada enviada\n" "$event_path"
    return 0
}

use_elixir() {
    [ "${FUNC_use_elixir:-n}" = "n" ] && return 0

    fetch_page "/inv/chest/" || return 1

    i=0
    while [ "$i" -lt 4 ]; do
        # Sempre usa o PRIMEIRO link atual. A lista muda depois de cada uso;
        # selecionar a linha i pulava itens e mesmo assim dizia "todos".
        click=`grep -o -E "/inv/chest/use/[0-9]+/1/[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        [ -n "$click" ] || break

        fetch_page "$click" || return 1
        i=$((i + 1))
        printf "Elixir: uso %s enviado\n" "$i"
    done

    if [ "$i" -gt 0 ]; then
        printf "Elixir: %s uso(s) enviado(s)\n" "$i"
    else
        printf "Elixir: nenhum uso disponivel\n"
    fi
    return 0
}
