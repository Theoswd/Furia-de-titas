#!/bin/sh
# resource_guard.sh - politica central para qualquer gasto automatico.
# Regra padrao: negar o que nao estiver explicitamente permitido.

resource_log() {
    _rr="$1"; _ra="$2"; _rw="$3"; _rok="$4"
    printf '%s|%s|%s|%s|%s\n' "$(date +%s)" "$_rr" "$_ra" "$_rw" "$_rok" >> "$TMP/resource_ledger" 2>/dev/null
    unset _rr _ra _rw _rok
}

resource_allow() {
    _rr="$1"; _ra="${2:-0}"; _rw="$3"
    case "$_ra" in ''|*[!0-9]*) _ra=0 ;; esac

    case "$_rw" in
        blessing|cave_gold_boost|clan_help_gold)
            resource_log "$_rr" "$_ra" "$_rw" denied
            unset _rr _ra _rw
            return 1
            ;;
        cave_mission_silver)
            [ "$_rr" = "silver" ] || { resource_log "$_rr" "$_ra" "$_rw" denied; unset _rr _ra _rw; return 1; }
            resource_log "$_rr" "$_ra" "$_rw" allowed
            unset _rr _ra _rw
            return 0
            ;;
        *)
            resource_log "$_rr" "$_ra" "$_rw" denied
            unset _rr _ra _rw
            return 1
            ;;
    esac
}
