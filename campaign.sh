# campaign.sh - Campanha com executor sequencial e preempcao por prioridade.
[ -f "$TWMDIR/action_runner.sh" ] && . "$TWMDIR/action_runner.sh"

campaign_func() {
    printf "Campaign\n"

    if command -v activity_run_links >/dev/null 2>&1; then
        activity_run_links \
            "/campaign/" \
            '/campaign/(go|fight|attack|end)/[?]r=[0-9]+' \
            90 \
            "Campaign"
        _rc=$?
        [ "$_rc" -eq 2 ] && { unset _rc; return 2; }
        [ "$_rc" -ne 0 ] && { unset _rc; return 1; }
        unset _rc
        printf "Campaign ok\n"
        return 0
    fi

    fetch_page "/campaign/"
    CAMPAIGN=`grep -o -E '/campaign/(go|fight|attack|end)/[?]r[=][0-9]+' "$TMP/SRC" | head -n 1`
    BREAK=$(($(date +%s) + 90))

    while [ -n "$CAMPAIGN" ] && [ "$(date +%s)" -lt "$BREAK" ]; do
        fetch_page "$CAMPAIGN" || break
        RESULT=`echo "$CAMPAIGN" | cut -d'/' -f3`
        printf "Campaign -> %s\n" "$RESULT"
        CAMPAIGN=`grep -o -E '/campaign/(go|fight|attack|end)/[?]r[=][0-9]+' "$TMP/SRC" | head -n 1`
    done

    printf "Campaign ok\n"
}
