#!/bin/sh
# state.sh - estado atomico por conta para scheduler, eventos e painel.
# Nao acessa a rede. Todos os arquivos ficam dentro de $TMP.

_state_atomic_write() {
    _sf="$1"
    _st="${_sf}.$$"
    cat > "$_st" || { rm -f "$_st" 2>/dev/null; return 1; }
    mv "$_st" "$_sf"
}

runtime_state_write() {
    _sa="$1"; _sp="$2"; _ss="$3"; _sd="${4:-}"
    {
        printf 'timestamp=%s\n' "$(date +%s)"
        printf 'activity=%s\n' "$_sa"
        printf 'page=%s\n' "$_sp"
        printf 'status=%s\n' "$_ss"
        [ -n "$_sd" ] && printf 'detail=%s\n' "$_sd"
    } | _state_atomic_write "$TMP/runtime_state"
    unset _sa _sp _ss _sd
}

event_lock_start() {
    _se="$1"
    {
        printf 'event=%s\n' "$_se"
        printf 'status=running\n'
        printf 'pid=%s\n' "$$"
        printf 'started=%s\n' "$(date +%s)"
        printf 'updated=%s\n' "$(date +%s)"
    } | _state_atomic_write "$TMP/event_lock"
    unset _se
}

event_lock_active() {
    [ -s "$TMP/event_lock" ] || return 1
    _ls=""; _lp=""
    while IFS='=' read -r _lk _lv; do
        case "$_lk" in
            status) _ls="$_lv" ;;
            pid)    _lp="$_lv" ;;
        esac
    done < "$TMP/event_lock"
    [ "$_ls" = "running" ] || { unset _ls _lp _lk _lv; return 1; }
    case "$_lp" in
        ''|*[!0-9]*) rm -f "$TMP/event_lock" 2>/dev/null; unset _ls _lp _lk _lv; return 1 ;;
    esac
    if kill -0 "$_lp" 2>/dev/null; then
        unset _ls _lp _lk _lv
        return 0
    fi
    rm -f "$TMP/event_lock" 2>/dev/null
    unset _ls _lp _lk _lv
    return 1
}

event_lock_finish() {
    _se="${1:-evento}"
    _sr="${2:-finished}"
    {
        printf 'event=%s\n' "$_se"
        printf 'status=%s\n' "$_sr"
        printf 'finished=%s\n' "$(date +%s)"
    } | _state_atomic_write "$TMP/last_event"
    rm -f "$TMP/event_lock" 2>/dev/null
    unset _se _sr
}

combat_state_write() {
    _ce="$1"; _cs="$2"; _ca="${3:-}"; _ch="${4:-}"
    {
        printf 'event=%s\n' "$_ce"
        printf 'status=%s\n' "$_cs"
        printf 'action=%s\n' "$_ca"
        printf 'hp=%s\n' "$_ch"
        printf 'updated=%s\n' "$(date +%s)"
    } | _state_atomic_write "$TMP/combat_state"
    unset _ce _cs _ca _ch
}

combat_state_clear() {
    rm -f "$TMP/combat_state" 2>/dev/null
}
