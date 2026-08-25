# career.sh - Carreira com missao de cla e executor sequencial seguro.
[ -f "$TWMDIR/action_runner.sh" ] && . "$TWMDIR/action_runner.sh"

career_func() {
    printf "Career\n"
    fetch_page "/career/" || return 1

    # Toma a missao #6 quando houver oportunidade, mas nao exige que o primeiro
    # estado seja attack: uma recompensa take pendente tambem deve ser tratada.
    if grep -q -E '/career/(attack|take)/[?]r=[0-9]+' "$TMP/SRC" 2>/dev/null; then
        checkQuest 6 apply 2>/dev/null
    fi

    if command -v activity_run_links >/dev/null 2>&1; then
        activity_run_links \
            "/career/" \
            '/career/(attack|take)/[?]r=[0-9]+' \
            60 \
            "Career"
        _rc=$?
        [ "$_rc" -eq 2 ] && { unset _rc; return 2; }
        [ "$_rc" -ne 0 ] && { unset _rc; return 1; }
        unset _rc
    else
        CAREER=`grep -o -E '/career/(attack|take)/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        BREAK=$(($(date +%s) + 60))
        while [ -n "$CAREER" ] && [ "$(date +%s)" -lt "$BREAK" ]; do
            fetch_page "$CAREER" || break
            RESULT=`echo "$CAREER" | cut -d'/' -f3`
            printf "Career -> %s\n" "$RESULT"
            sleep 0.5
            CAREER=`grep -o -E '/career/(attack|take)/[?]r=[0-9]+' "$TMP/SRC" | sed -n '1p'`
        done
    fi

    checkQuest 6 end 2>/dev/null
    printf "Career ok\n"
    return 0
}
