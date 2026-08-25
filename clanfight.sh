# clanfight.sh - Torneio do Cla
# Mantem os nomes e caminhos do jogo; evita URL vazia e falso "ok".

clanfight_parse() {
    _cf_file="${1:-$TMP/SRC}"
    [ -s "$_cf_file" ] || return 1

    CF_ATK=`grep -o -E '/clanfight/attack/[?]r=[0-9]+' "$_cf_file" | sed -n '1p'`
    CF_ATKRND=`grep -o -E '/clanfight/attackrandom/[?]r=[0-9]+' "$_cf_file" | sed -n '1p'`
    CF_DODGE=`grep -o -E '/clanfight/dodge/[?]r=[0-9]+' "$_cf_file" | sed -n '1p'`
    CF_HEAL=`grep -o -E '/clanfight/heal/[?]r=[0-9]+' "$_cf_file" | sed -n '1p'`
    CF_GRASS=`grep -o -E '/clanfight/grass/[?]r=[0-9]+' "$_cf_file" | sed -n '1p'`

    CF_HP=`grep -o -E "(hp)[^A-Za-z0-9]{1,4}[0-9]{1,7}" "$_cf_file" | grep -o -E '[0-9]{1,7}' | sed -n '1p'`
    CF_ENEMY_HP=`grep -o -E "(nbsp)[^A-Za-z0-9]{1,2}[0-9]{1,7}" "$_cf_file" | grep -o -E '[0-9]{1,7}' | sed -n '1p'`
    CF_CLAN=`grep -o -E '([[:upper:]][[:lower:]]{0,20}( [[:upper:]][[:lower:]]{0,17})?)[[:space:]]\(' "$_cf_file" | sed -n 's, [(],,;s, ,_,;2p'`

    case "$CF_HP" in ''|*[!0-9]*) CF_HP=0 ;; esac
    case "$CF_ENEMY_HP" in ''|*[!0-9]*) CF_ENEMY_HP=0 ;; esac
    unset _cf_file
    return 0
}

clanfight_em_batalha() {
    [ -n "${CF_ATK:-}" ] || [ -n "${CF_ATKRND:-}" ] || \
    [ -n "${CF_DODGE:-}" ] || [ -n "${CF_HEAL:-}" ]
}

clanfight_link_valido() {
    case "$1" in
        /clanfight/attack/?r=*|/clanfight/attackrandom/?r=*|/clanfight/dodge/?r=*|/clanfight/heal/?r=*|/clanfight/grass/?r=*) return 0 ;;
        *) return 1 ;;
    esac
}

clanfight_fight() {
    LA=4
    HPER=48
    RPER=15
    CF_STARTED=0
    CF_OLD_HP=0
    CF_LAST_DODGE=$(( $(date +%s) - 30 ))
    CF_LAST_HEAL=$(( $(date +%s) - 100 ))
    CF_LAST_ATK=$(( $(date +%s) - LA ))
    CF_DEADLINE=$(( $(date +%s) + 600 ))

    case "${CF_FULL:-0}" in ''|*[!0-9]*) CF_FULL=0 ;; esac

    while [ "$(date +%s)" -lt "$CF_DEADLINE" ]; do
        [ -s "$TMP/SRC" ] || fetch_page "/clanfight/" "$TMP/SRC" || return 1

        if command -v is_logged_in >/dev/null 2>&1; then
            _cf_page=`cat "$TMP/SRC" 2>/dev/null`
            if ! is_logged_in "$_cf_page"; then
                printf "ClanFight: sessao perdida\n"
                unset _cf_page
                return 1
            fi
            unset _cf_page
        fi

        clanfight_parse "$TMP/SRC" || return 1

        if ! clanfight_em_batalha; then
            if [ "$CF_STARTED" -eq 1 ]; then
                fetch_page "/clanfight/" "$TMP/SRC" || return 1
                clanfight_parse "$TMP/SRC" || return 1
                if ! clanfight_em_batalha; then
                    command -v combat_state_write >/dev/null 2>&1 && combat_state_write clanfight finished "" "$CF_HP"
                    printf "ClanFight: batalha encerrada\n"
                    return 0
                fi
            else
                printf "ClanFight: batalha ainda nao disponivel\n"
                return 3
            fi
        fi

        CF_STARTED=1
        _cf_now=`date +%s`
        _cf_action=""
        _cf_label="waiting"

        if [ "$CF_FULL" -gt 0 ] && [ "$CF_HP" -gt 0 ]; then
            _cf_heal_limit=$(( CF_FULL * HPER / 100 ))
        else
            _cf_heal_limit=0
        fi

        if [ "$_cf_heal_limit" -gt 0 ] && [ "$CF_HP" -lt "$_cf_heal_limit" ] && \
           [ $((_cf_now - CF_LAST_HEAL)) -ge 90 ] && [ -n "$CF_HEAL" ]; then
            _cf_action="$CF_HEAL"
            _cf_label="heal"
        elif [ "$CF_OLD_HP" -gt 0 ] && [ "$CF_HP" -lt "$CF_OLD_HP" ] && \
             [ $((_cf_now - CF_LAST_DODGE)) -ge 20 ] && [ -n "$CF_DODGE" ]; then
            _cf_action="$CF_DODGE"
            _cf_label="dodge"
        elif [ $((_cf_now - CF_LAST_ATK)) -ge "$LA" ]; then
            _cf_random=n
            if [ -n "$CF_ATKRND" ]; then
                if [ "$CF_HP" -gt 0 ] && [ "$CF_ENEMY_HP" -gt $(( CF_HP + (CF_HP * RPER / 100) )) ]; then
                    _cf_random=y
                elif [ -n "$CF_CLAN" ] && [ -s "$TMP/callies.txt" ] && grep -q -F "$CF_CLAN" "$TMP/callies.txt" 2>/dev/null; then
                    _cf_random=y
                fi
            fi
            if [ "$_cf_random" = "y" ]; then
                _cf_action="$CF_ATKRND"
                _cf_label="attackrandom"
            elif [ -n "$CF_ATK" ]; then
                _cf_action="$CF_ATK"
                _cf_label="attack"
            fi
            unset _cf_random
        fi

        CF_OLD_HP="$CF_HP"

        if [ -n "$_cf_action" ]; then
            if ! clanfight_link_valido "$_cf_action"; then
                printf "ClanFight: link invalido bloqueado: %s\n" "$_cf_action"
                return 1
            fi
            command -v combat_state_write >/dev/null 2>&1 && combat_state_write clanfight fighting "$_cf_label" "$CF_HP"
            if ! fetch_page "$_cf_action" "$TMP/SRC"; then
                printf "ClanFight: falha em %s\n" "$_cf_label"
                return 1
            fi
            case "$_cf_label" in
                heal) CF_LAST_HEAL=$_cf_now ;;
                dodge) CF_LAST_DODGE=$_cf_now ;;
                attack|attackrandom) CF_LAST_ATK=$_cf_now ;;
            esac

            if [ "$_cf_label" = "heal" ]; then
                clanfight_parse "$TMP/SRC" >/dev/null 2>&1 || :
                if [ -n "${CF_GRASS:-}" ] && clanfight_link_valido "$CF_GRASS"; then
                    fetch_page "$CF_GRASS" "$TMP/SRC" || return 1
                fi
            fi
        else
            command -v combat_state_write >/dev/null 2>&1 && combat_state_write clanfight fighting waiting "$CF_HP"
            fetch_page "/clanfight/" "$TMP/SRC" || return 1
        fi

        unset _cf_action _cf_label _cf_heal_limit _cf_now
        sleep 1
    done

    command -v combat_state_write >/dev/null 2>&1 && combat_state_write clanfight timeout "" "${CF_HP:-0}"
    printf "ClanFight: timeout sem prova de fim; nao marcado como concluido\n"
    return 4
}

clanfight_start() {
    case `date +%H:%M` in
        10:5[5-9]|18:5[5-9]) ;;
        *) return 3 ;;
    esac

    printf "ClanFight: preparando Torneio do Cla\n"

    fetch_page "/train" "$TMP/CLANFIGHT_TRAIN" || return 1
    CF_FULL=`grep -o -E '\(([0-9]+)\)' "$TMP/CLANFIGHT_TRAIN" | sed 's/[()]//g' | sed -n '1p'`
    case "$CF_FULL" in ''|*[!0-9]*) CF_FULL=0 ;; esac

    fetch_page "/clanfight/?close=reward" "$TMP/SRC" >/dev/null 2>&1 || :
    fetch_page "/clanfight/enterFight" "$TMP/SRC" || return 1

    while :; do
        case `date +%M:%S` in 59:[3-5][0-9]) break ;; esac
        clanfight_parse "$TMP/SRC" >/dev/null 2>&1 || :
        clanfight_em_batalha && break
        sleep 3
    done

    fetch_page "/clanfight/enterFight" "$TMP/SRC" || return 1

    _cf_wait_end=$(( $(date +%s) + 90 ))
    while [ "$(date +%s)" -lt "$_cf_wait_end" ]; do
        clanfight_parse "$TMP/SRC" >/dev/null 2>&1 || :
        if clanfight_em_batalha; then
            unset _cf_wait_end
            clanfight_fight
            return $?
        fi
        fetch_page "/clanfight/" "$TMP/SRC" || return 1
        sleep 3
    done

    unset _cf_wait_end
    printf "ClanFight: nao foi possivel confirmar inicio da batalha\n"
    return 4
}
