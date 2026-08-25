# shellcheck disable=SC2148
arena_fault() {
    (
        run_curl_exec "${URL}/fault" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    BREAK=$(($(date +%s) + 10))

    while grep -q -o '/fault/attack' "$TMP/SRC" && [ "$(date +%s)" -lt "$BREAK" ]; do
        ACCESS=`grep -o -E '(/fault/attack/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        [ -n "$ACCESS" ] || break

        if command -v priority_guard >/dev/null 2>&1; then
            priority_guard || return 2
        fi

        (
            run_curl_exec "${URL}${ACCESS}" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17 || return 1
        printf "%s\n" "$ACCESS"
        sleep 1
    done
    printf "fault: ciclo encerrado\n"
}

arena_collFight() {
    (
        run_curl_exec "${URL}/collfight/enterFight" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17 || return 1

    if grep -q -o '/collfight/' "$TMP/SRC"; then
        printf "collfight ...\n"
        ACCESS=`sed 's/href=/\n/g' "$TMP/SRC" | grep 'collfight/take' | head -n1 | awk -F\' '{ print $2 }'`
        [ -n "$ACCESS" ] || return 1

        (
            run_curl_exec "${URL}${ACCESS}" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17 || return 1

        (
            run_curl_exec "${URL}/collfight/enterFight" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17 || return 1
        printf "collfight: acoes enviadas\n"
        return 0
    fi
    return 1
}

arena_duel() {
    printf "Arena\n"

    ARENA_ATTACKS=0
    export ARENA_ATTACKS

    checkQuest 3 apply 2>/dev/null
    checkQuest 4 apply 2>/dev/null

    fetch_page "/arena/" || return 1

    BREAK=$(($(date +%s) + 60))
    count=0

    until grep -q -o 'lab/wizard' "$TMP/SRC" || [ "$(date +%s)" -gt "$BREAK" ]; do
        if command -v priority_guard >/dev/null 2>&1; then
            priority_guard || {
                ARENA_ATTACKS=$count
                export ARENA_ATTACKS
                return 2
            }
        fi

        ACCESS=`grep -o -E '(/arena/attack/1/[?]r[=][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        if [ -z "$ACCESS" ]; then
            printf "  Arena sem ataques disponiveis\n"
            break
        fi

        if ! fetch_page "$ACCESS"; then
            printf "  Arena: falha ao enviar ataque\n"
            ARENA_ATTACKS=$count
            export ARENA_ATTACKS
            return 1
        fi

        if command -v is_logged_in >/dev/null 2>&1; then
            _arena_page=`cat "$TMP/SRC" 2>/dev/null`
            if ! is_logged_in "$_arena_page"; then
                printf "  Arena: sessao perdida apos ataque\n"
                unset _arena_page
                ARENA_ATTACKS=$count
                export ARENA_ATTACKS
                return 1
            fi
            unset _arena_page
        fi

        count=$((count + 1))
        ARENA_ATTACKS=$count
        export ARENA_ATTACKS
        printf "  Arena: ataque %s enviado\n" "$count"
        printf '%s\n' "$count" > "$TMP/arena_attacks" 2>/dev/null
        sleep 1
    done

    if [ "${FUNC_arena_sell_all:-n}" = "y" ] && [ "$count" -gt 0 ]; then
        fetch_page "/inv/bag/" || return 1
        SELL=`grep -o -E '(/inv/bag/sellAll/1/[?]r[=][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        if [ -n "$SELL" ]; then
            fetch_page "$SELL" && printf "Arena: venda total enviada\n"
        fi
    fi

    checkQuest 3 end 2>/dev/null
    checkQuest 4 end 2>/dev/null

    if [ "$count" -gt 0 ]; then
        printf "Arena: %s ataque(s) enviado(s)\n" "$count"
        return 0
    fi

    printf "Arena: nenhuma acao executavel agora\n"
    return 3
}

arena_fullmana() {
    printf "energy arena ...\n"
    (
        run_curl_exec "${URL}/arena/quit" | sed "s/href='/\n/g" | grep 'attack/1' | head -n1 | awk -F/ '{ print $5 }' | tr -cd '[:digit:]' > "$TMP/ARENA"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17 || return 1
    [ -s "$TMP/ARENA" ] || return 1

    printf " - 1 Attack...\n"
    (
        run_curl_exec "${URL}/arena/attack/1/?r=`cat "$TMP/ARENA"`" | sed "s/href='/\n/g" | grep 'arena/lastPlayer' | head -n1 | awk -F\' '{ print $1 }' | tr -cd '[:digit:]' > "$TMP/ATK1"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17 || return 1
    [ -s "$TMP/ATK1" ] || return 1

    printf " - Full Attack...\n"
    (
        run_curl_exec "${URL}/arena/lastPlayer/?r=`cat "$TMP/ATK1"`&fullmana=true" > /dev/null
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17 || return 1
    printf "Energy arena: acao enviada\n"
}
