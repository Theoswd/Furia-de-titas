# shellcheck disable=SC2148
arena_fault() {
    (
        run_curl_exec "${URL}/fault" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    BREAK=$(($(date +%s) + 10))

    # CORRECAO: era OR (||), entao o loop podia continuar depois do timeout
    # enquanto o link existisse. Agora exige link E tempo restante.
    while grep -q -o '/fault/attack' "$TMP/SRC" && [ "$(date +%s)" -lt "$BREAK" ]; do
        ACCESS=`grep -o -E '(/fault/attack/[^A-Za-z0-9]r[^A-Za-z0-9][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        [ -n "$ACCESS" ] || break
        command -v priority_guard >/dev/null 2>&1 && priority_guard || {
            command -v priority_guard >/dev/null 2>&1 && return 2
        }
        (
            run_curl_exec "${URL}${ACCESS}" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "%s\n" "$ACCESS"
        sleep 1
    done
    printf "fault (ok)\n"
}

arena_collFight() {
    (
        run_curl_exec "${URL}/collfight/enterFight" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    if grep -q -o '/collfight/' "$TMP/SRC"; then
        printf "collfight ...\n"
        printf "/collfight/enterFight\n"
        ACCESS=`sed 's/href=/\n/g' "$TMP/SRC" | grep 'collfight/take' | head -n1 | awk -F\' '{ print $2 }'`
        [ -n "$ACCESS" ] || return 1
        (
            run_curl_exec "${URL}${ACCESS}" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "%s\n" "$ACCESS"
        (
            run_curl_exec "${URL}/collfight/enterFight" > /dev/null
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        printf "/collfight/enterFight\n"
        printf "collfight (ok)\n"
    fi
}

arena_duel() {
    printf "Arena\n"

    checkQuest 3 apply 2>/dev/null
    checkQuest 4 apply 2>/dev/null

    fetch_page "/arena/" || return 1

    BREAK=$(($(date +%s) + 60))
    count=0

    until grep -q -o 'lab/wizard' "$TMP/SRC" || [ "$(date +%s)" -gt "$BREAK" ]; do
        command -v priority_guard >/dev/null 2>&1 && priority_guard || {
            command -v priority_guard >/dev/null 2>&1 && return 2
        }

        ACCESS=`grep -o -E '(/arena/attack/1/[?]r[=][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        if [ -z "$ACCESS" ]; then
            printf "  Arena sem ataques disponiveis\n"
            break
        fi

        fetch_page "$ACCESS" || break
        count=$((count + 1))
        printf "  Attack %s\n" "$count"
        printf '%s\n' "$count" > "$TMP/arena_attacks" 2>/dev/null
        sleep 0.6
    done

    # Vender inventario virou uma politica separada. Por padrao nao vende.
    if [ "${FUNC_arena_sell_all:-n}" = "y" ]; then
        fetch_page "/inv/bag/"
        SELL=`grep -o -E '(/inv/bag/sellAll/1/[?]r[=][0-9]+)' "$TMP/SRC" | sed -n '1p'`
        if [ -n "$SELL" ]; then
            fetch_page "$SELL"
            printf "Sell all items ok\n"
        fi
    fi

    checkQuest 3 end 2>/dev/null
    checkQuest 4 end 2>/dev/null

    printf "Arena ok (%s ataque(s))\n" "$count"
}

arena_fullmana() {
    printf "energy arena ...\n"
    (
        run_curl_exec "${URL}/arena/quit" | sed "s/href='/\n/g" | grep 'attack/1' | head -n1 | awk -F/ '{ print $5 }' | tr -cd '[:digit:]' > "$TMP/ARENA"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    [ -s "$TMP/ARENA" ] || return 1
    printf " - 1 Attack...\n"
    (
        run_curl_exec "${URL}/arena/attack/1/?r=`cat "$TMP/ARENA"`" | sed "s/href='/\n/g" | grep 'arena/lastPlayer' | head -n1 | awk -F\' '{ print $1 }' | tr -cd '[:digit:]' > "$TMP/ATK1"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    [ -s "$TMP/ATK1" ] || return 1
    printf " - Full Attack...\n"
    (
        run_curl_exec "${URL}/arena/lastPlayer/?r=`cat "$TMP/ATK1"`&fullmana=true" > /dev/null
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "Energy arena ok\n"
}
