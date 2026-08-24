clan_id() {
    cd "$TMP" || return 1

    fetch_page "/clan" "$TMP/CLD"

    CLD=`grep -o -E '/clan/[0-9]+/' "$TMP/CLD" | head -n 1 | awk -F'/' '{ print $3 }'`

    if [ -z "$CLD" ]; then
        printf "CLAN ID not found!\n"
        return 1
    else
        echo "$CLD" > "$TMP/CLD"
    fi
}

checkQuest() {
    quest_id="$1"
    action="$2"

    if [ "${FUNC_clan_missions:-y}" != "y" ]; then
        return 1
    fi

    if [ -z "$CLD" ]; then
        printf "CLAN ID not available, trying to fetch it.\n"
        clan_id
        if [ -z "$CLD" ]; then
            printf "Failed to retrieve CLAN ID.\n"
            return 1
        fi
    fi

    fetch_page "/clan/${CLD}/quest/"

    if [ ! -s "$TMP/SRC" ]; then
        printf "Source file $TMP/SRC is empty, fetch_page may have failed.\n"
        return 1
    fi

    case "$action" in
        apply)
            click=`grep -o -E "/quest/(take|help)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'`
            ;;
        end)
            click=`grep -o -E "/quest/(deleteHelp|end)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'`
            ;;
        *)
            return 1
            ;;
    esac

    if [ -n "$click" ]; then
        fetch_page "$click"
        return 0
    fi

    return 1
}

# Masmorra do Cla.
# Pagina real: /clandungeon/
# Ataque gratuito: /clandungeon/attack/?r=N
# Retorno: 0 somente quando pelo menos um ataque foi realmente enviado.
# Isso impede o scheduler de marcar a janela como concluida quando a pagina
# falha, quando o clan ID nao existe ou quando nenhum ataque foi realizado.
clanDungeon() {
    [ -n "$CLD" ] || return 1

    printf "Masmorra do cla\n"
    fetch_page "/clandungeon/" "$TMP/DUNGEON" || return 1
    [ -s "$TMP/DUNGEON" ] || return 1

    _golpes=`sed 's/<[^>]*>//g' "$TMP/DUNGEON" | grep -oE "Golpes mais:[^0-9]{0,8}[0-9]{1,3}" | grep -oE '[0-9]{1,3}$' | head -n1`
    [ -n "$_golpes" ] && printf "Masmorra: %s golpes disponiveis\n" "$_golpes"

    # SOMENTE GOLPES GRATUITOS. Limite adicional de 10 ataques por chamada,
    # mesmo que o HTML venha inconsistente. Nunca segue links de compra.
    _br=$(($(date +%s) + 180))
    _n=0
    while [ "$(date +%s)" -lt "$_br" ] && [ "$_n" -lt 10 ]; do
        _cl=`grep -o -E '/clandungeon/attack/[?]r=[0-9]+' "$TMP/DUNGEON" | sed -n 1p`
        [ -n "$_cl" ] || break

        if ! fetch_page "$_cl" "$TMP/DUNGEON"; then
            printf "Masmorra: falha ao enviar ataque gratuito\n"
            break
        fi

        _n=$((_n + 1))
        printf "Masmorra: ataque gratuito %s/10\n" "$_n"
        sleep 1
    done

    if [ "$_n" -gt 0 ]; then
        printf "Masmorra do cla ok (%s ataque(s) gratuito(s))\n" "$_n"
        unset _golpes _br _cl
        return 0
    fi

    printf "Masmorra: nenhum ataque gratuito executado agora\n"
    unset _golpes _br _n _cl
    return 1
}

# Conta e lider/oficial do cla?
clan_lider() {
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/" "$TMP/CLANPG"
    grep -q -E "/clan/${CLD}/[0-9]+/adm/" "$TMP/CLANPG"
}

estatua_liberada() {
    _h=${FUNC_estatua_horas:-6}
    case "$_h" in ''|*[!0-9]*) _h=6 ;; esac
    _u=`cat "$TMP/last_estatua" 2>/dev/null`
    case "$_u" in ''|*[!0-9]*) _u=0 ;; esac
    [ $(( $(date +%s) - _u )) -ge $((_h * 3600)) ]
}
estatua_marcar() { date +%s > "$TMP/last_estatua" 2>/dev/null; }

clan_statue() {
    [ "${FUNC_clan_statue:-y}" = "y" ] || return 1
    [ -n "$CLD" ] || return 1

    if ! clan_lider; then
        return 1
    fi

    estatua_liberada || return 1

    fetch_page "/clan/${CLD}/built/" "$TMP/STATUE"
    [ -s "$TMP/STATUE" ] || return 1

    for _up in goldUpgrade silverUpgrade; do
        _cl=`grep -o -E "/clan/${CLD}/built/[?]${_up}=true&r=[0-9]+" "$TMP/STATUE" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl" "$TMP/STATUE2"
            fetch_page "/clan/${CLD}/built/" "$TMP/STATUE2"
            if grep -q "${_up}=true" "$TMP/STATUE2" 2>/dev/null; then
                case "$_up" in
                    goldUpgrade)   printf "Estatua: bonus de OURO nao ativou (ouro do cla insuficiente)\n" ;;
                    silverUpgrade) printf "Estatua: bonus de PRATA nao ativou (prata do cla insuficiente)\n" ;;
                esac
            else
                case "$_up" in
                    goldUpgrade)   printf "Estatua do cla: bonus de OURO ativado\n" ;;
                    silverUpgrade) printf "Estatua do cla: bonus de PRATA ativado\n" ;;
                esac
            fi
        fi
    done
    estatua_marcar
    unset _up _cl
    return 0
}

clanQuests() {
    if [ -z "$CLD" ]; then
        return
    fi

    fetch_page "/clan/${CLD}/quest/"

    QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    CQ_BREAK=$(($(date +%s) + 90))
    while [ -n "$QUEST" ] && [ "$(date +%s)" -lt "$CQ_BREAK" ]; do
        fetch_page "$QUEST"
        printf "Clan quest processed\n"
        fetch_page "/clan/${CLD}/quest/"
        QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    done
}
