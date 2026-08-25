clan_id() {
    cd "$TMP" || return 1

    fetch_page "/clan" "$TMP/CLD"
    CLD=`grep -o -E '/clan/[0-9]+/' "$TMP/CLD" | head -n 1 | awk -F'/' '{ print $3 }'`

    if [ -z "$CLD" ]; then
        printf "CLAN ID not found!\n"
        return 1
    fi
    echo "$CLD" > "$TMP/CLD"
}

checkQuest() {
    quest_id="$1"
    action="$2"

    [ "${FUNC_clan_missions:-y}" = "y" ] || return 1

    if [ -z "$CLD" ]; then
        printf "CLAN ID not available, trying to fetch it.\n"
        clan_id || return 1
    fi

    fetch_page "/clan/${CLD}/quest/" || return 1
    [ -s "$TMP/SRC" ] || return 1

    case "$action" in
        apply) click=`grep -o -E "/quest/(take|help)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'` ;;
        end)   click=`grep -o -E "/quest/(deleteHelp|end)/$quest_id/\?r=[0-9]{8}" "$TMP/SRC" | sed -n '1p'` ;;
        *) return 1 ;;
    esac

    [ -n "$click" ] || return 1
    fetch_page "$click"
}

# Masmorra do Cla.
# Fluxo observado: /clandungeon/ pode oferecer primeiro /clandungeon/executar
# e somente depois o link gratuito /clandungeon/attack/?r=N.
# Nunca segue compra/pagamento; no maximo 10 golpes gratuitos por chamada.
clanDungeon() {
    [ -n "$CLD" ] || return 1

    printf "Masmorra do cla\n"
    fetch_page "/clandungeon/" "$TMP/DUNGEON" || return 1
    [ -s "$TMP/DUNGEON" ] || return 1

    _golpes=`sed 's/<[^>]*>//g' "$TMP/DUNGEON" | grep -oE "Golpes mais:[^0-9]{0,8}[0-9]{1,3}" | grep -oE '[0-9]{1,3}$' | head -n1`
    [ -n "$_golpes" ] && printf "Masmorra: %s golpes disponiveis\n" "$_golpes"

    # SOMENTE GOLPES GRATUITOS.
    _br=$(($(date +%s) + 180))
    _n=0
    while [ "$(date +%s)" -lt "$_br" ] && [ "$_n" -lt 10 ]; do
        _cl=`grep -o -E '/clandungeon/attack/[?]r=[0-9]+' "$TMP/DUNGEON" | sed -n '1p'`

        if [ -z "$_cl" ]; then
            _exec=`grep -o -E '/clandungeon/executar(/[?]r=[0-9]+)?' "$TMP/DUNGEON" | sed -n '1p'`
            if [ -n "$_exec" ]; then
                printf "Masmorra: entrando na execucao\n"
                fetch_page "$_exec" "$TMP/DUNGEON" || break
                _cl=`grep -o -E '/clandungeon/attack/[?]r=[0-9]+' "$TMP/DUNGEON" | sed -n '1p'`
            fi
        fi

        [ -n "$_cl" ] || break

        # Protecao adicional: apenas o caminho gratuito de ataque e aceito.
        case "$_cl" in
            /clandungeon/attack/?r=*) ;;
            *) printf "Masmorra: link nao gratuito ignorado\n"; break ;;
        esac

        if ! fetch_page "$_cl" "$TMP/DUNGEON"; then
            printf "Masmorra: falha ao enviar ataque gratuito\n"
            break
        fi

        _n=$((_n + 1))
        printf "Masmorra: ataque gratuito %s/10\n" "$_n"

        # Algumas respostas nao repetem o link seguinte: redescobre o estado.
        if ! grep -q -E '/clandungeon/(attack|executar)' "$TMP/DUNGEON" 2>/dev/null; then
            fetch_page "/clandungeon/" "$TMP/DUNGEON" || break
        fi
        sleep 1
    done

    if [ "$_n" -gt 0 ]; then
        printf "Masmorra do cla ok (%s ataque(s) gratuito(s))\n" "$_n"
        unset _golpes _br _cl _exec _n
        return 0
    fi

    printf "Masmorra: nenhum ataque gratuito executado agora\n"
    unset _golpes _br _n _cl _exec
    return 1
}

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
    clan_lider || return 1
    estatua_liberada || return 1

    fetch_page "/clan/${CLD}/built/" "$TMP/STATUE"
    [ -s "$TMP/STATUE" ] || return 1

    for _up in goldUpgrade silverUpgrade; do
        _cl=`grep -o -E "/clan/${CLD}/built/[?]${_up}=true&r=[0-9]+" "$TMP/STATUE" | sed -n '1p'`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl" "$TMP/STATUE2"
            fetch_page "/clan/${CLD}/built/" "$TMP/STATUE2"
            if grep -q "${_up}=true" "$TMP/STATUE2" 2>/dev/null; then
                case "$_up" in
                    goldUpgrade) printf "Estatua: bonus de OURO nao ativou (ouro do cla insuficiente)\n" ;;
                    silverUpgrade) printf "Estatua: bonus de PRATA nao ativou (prata do cla insuficiente)\n" ;;
                esac
            else
                case "$_up" in
                    goldUpgrade) printf "Estatua do cla: bonus de OURO ativado\n" ;;
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
    [ -n "$CLD" ] || return

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
