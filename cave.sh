# cave.sh - Caverna segura/POSIX para WSL e Termux.
# Ouro automatico e proibido. Speed-up de prata so e permitido quando houver
# missao de cla ativa que exige a rotina da caverna.

SILVER_SPENT_TOTAL=0
GOLD_SPENT_TOTAL=0
[ -f "$TWMDIR/resource_guard.sh" ] && . "$TWMDIR/resource_guard.sh"

read_speedup_silver_cost() {
    # O HTML varia; se o custo nao puder ser lido com seguranca, fica 0.
    _cs=`grep -o -E "silver\.png[^0-9]*[0-9][0-9,]*" "$TMP/SRC" 2>/dev/null | head -n1 | grep -o -E '[0-9][0-9,]*' | tail -n1 | tr -d ','`
    case "$_cs" in ''|*[!0-9]*) _cs=0 ;; esac
    SPEEDUP_SILVER_COST=$_cs
    unset _cs
}

check_cave_limits() {
    _gl=${CAVE_GOLD_LIMIT:-0}
    _sl=${CAVE_SILVER_LIMIT:-0}
    case "$_gl" in ''|*[!0-9]*) _gl=0 ;; esac
    case "$_sl" in ''|*[!0-9]*) _sl=0 ;; esac

    if [ "$_gl" -gt 0 ] && [ "${GOLD_SPENT_TOTAL:-0}" -ge "$_gl" ]; then
        printf "Limite de ouro atingido (%s/%s)\n" "${GOLD_SPENT_TOTAL:-0}" "$_gl"
        return 1
    fi
    if [ "$_sl" -gt 0 ] && [ "${SILVER_SPENT_TOTAL:-0}" -ge "$_sl" ]; then
        printf "Limite de prata atingido (%s/%s)\n" "${SILVER_SPENT_TOTAL:-0}" "$_sl"
        return 1
    fi
    unset _gl _sl
    return 0
}

set_cave_limits() {
    CAVE_GOLD_LIMIT=0
    CAVE_SILVER_LIMIT=${CAVE_SILVER_LIMIT:-0}
    _s=`get_config CAVE_SILVER_LIMIT 2>/dev/null`
    case "$_s" in ''|*[!0-9]*) _s=0 ;; esac
    CAVE_SILVER_LIMIT="$_s"
    unset _s
    printf "Caverna: ouro automatico bloqueado | limite prata=%s\n" "$CAVE_SILVER_LIMIT"
}

bottom_info() {
    printf "%s | HP %s (%s%%) | MP %s (%s%%)\n" \
        "${ACC:-conta}" "${NOWHP:--}" "${HPPER:--}" "${NOWMP:--}" "${MPPER:--}" > "$TMP/bottom_file"
    cat "$TMP/bottom_file"
}

cave_action() {
    _cv_link="$1"
    _cv_result="$2"
    _cv_mission="$3"

    [ -n "$_cv_link" ] || { unset _cv_link _cv_result _cv_mission; return 1; }

    case "$_cv_result" in
        speedUp)
            if [ "$_cv_mission" != "y" ]; then
                printf "Caverna: speed-up ignorado fora de missao do cla\n"
                unset _cv_link _cv_result _cv_mission
                return 2
            fi
            read_speedup_silver_cost
            if command -v resource_allow >/dev/null 2>&1; then
                resource_allow silver "${SPEEDUP_SILVER_COST:-0}" cave_mission_silver || {
                    printf "Caverna: speed-up de prata bloqueado pela politica\n"
                    unset _cv_link _cv_result _cv_mission
                    return 2
                }
            fi
            fetch_page "$_cv_link" || return 1
            SILVER_SPENT_TOTAL=$((SILVER_SPENT_TOTAL + ${SPEEDUP_SILVER_COST:-0}))
            printf "Speed up mining\n"
            ;;
        gather)
            fetch_page "$_cv_link" || return 1
            printf "Start mining\n"
            ;;
        down)
            fetch_page "$_cv_link" || return 1
            printf "New search\n"
            ;;
        runaway)
            fetch_page "$_cv_link" || return 1
            printf "Running away\n"
            ;;
        *) unset _cv_link _cv_result _cv_mission; return 1 ;;
    esac

    unset _cv_link _cv_result _cv_mission
    return 0
}

# Modo dedicado -cv. Mantido, mas sem nenhum gasto de ouro e sem speed-up de
# prata fora de missao do cla.
cave_start() {
    clan_id 2>/dev/null
    set_cave_limits
    fetch_page "/cave/" || return 1

    _end=$(( $(date +%s) + 240 ))
    while echo "$RUN" | grep -q -E '[-]cv' && [ "$(date +%s)" -lt "$_end" ]; do
        # Qualquer boost de ouro encontrado e explicitamente ignorado.
        if grep -q -E '/cave/chance/2/[?]r=[0-9]+' "$TMP/SRC" 2>/dev/null; then
            command -v resource_allow >/dev/null 2>&1 && resource_allow gold 0 cave_gold_boost >/dev/null 2>&1
            printf "Caverna: boost de ouro ignorado\n"
        fi

        _attack=`grep -o -E '/cave/attack/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        _run=`grep -o -E '/cave/runaway/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        if [ -n "$_attack" ] && [ -n "$_run" ]; then
            printf "Monster found - running away (no gold spent)\n"
            fetch_page "$_run" || break
            fetch_page "/cave/" || break
            continue
        fi

        _cave=`grep -o -E '/cave/(gather|down|runaway|speedUp)/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        [ -n "$_cave" ] || break
        _result=`echo "$_cave" | cut -d'/' -f3`
        cave_action "$_cave" "$_result" n || break
        fetch_page "/cave/" || break
        check_cave_limits || break
    done
    unset _end _attack _run _cave _result
}

cave_routine() {
    printf "Cave\n"

    _mission=n
    if checkQuest 5 apply 2>/dev/null; then
        _mission=y
        count=0
        printf "Missao do cla da caverna ativa\n"
    else
        count=8
    fi

    CAVE_BREAK=$(($(date +%s) + 240))
    fetch_page "/cave/" || return 1

    while [ "$(date +%s)" -lt "$CAVE_BREAK" ]; do
        command -v priority_guard >/dev/null 2>&1 && priority_guard || {
            command -v priority_guard >/dev/null 2>&1 && { unset _mission; return 2; }
        }

        # Regra absoluta: nunca usa /cave/chance/2 (ouro).
        if grep -q -E '/cave/chance/2/[?]r=[0-9]+' "$TMP/SRC" 2>/dev/null; then
            command -v resource_allow >/dev/null 2>&1 && resource_allow gold 0 cave_gold_boost >/dev/null 2>&1
        fi

        CAVE=`grep -o -E '/cave/(gather|down|runaway|speedUp)/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        [ -n "$CAVE" ] || { printf "Caverna sem acao disponivel agora\n"; break; }
        RESULT=`echo "$CAVE" | cut -d'/' -f3`

        if [ "$RESULT" = "speedUp" ] && [ "$_mission" != "y" ]; then
            printf "Caverna: speed-up aguardando missao do cla\n"
            break
        fi

        cave_action "$CAVE" "$RESULT" "$_mission"
        _rc=$?
        [ "$_rc" -eq 0 ] || break
        [ "$RESULT" = "down" ] && count=$((count + 1))

        fetch_page "/cave/" || break
    done

    [ "$_mission" = "y" ] && checkQuest 5 end 2>/dev/null
    printf "Cave ok\n"
    unset _mission _rc CAVE RESULT
}
