clan_id() {
    cd "$TMP" || return 1

    fetch_page "/clan" "$TMP/CLD" || return 1
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

    # IMPORTANTE: o fluxo legado nunca mais segue /help. Toda ajuda fica
    # exclusivamente em cq_ajudar(), onde ha politica de custo separada.
    # O token r nao e tratado como tendo tamanho fixo: o jogo pode mudar a
    # quantidade de digitos sem quebrar a tomada/coleta da missao.
    case "$action" in
        apply) click=`grep -o -E "/quest/take/$quest_id/\?r=[0-9]+" "$TMP/SRC" | sed -n '1p'` ;;
        end)   click=`grep -o -E "/quest/(deleteHelp|end)/$quest_id/\?r=[0-9]+" "$TMP/SRC" | sed -n '1p'` ;;
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
        case "$_cl" in
            /clandungeon/attack/?r=*) ;;
            *) printf "Masmorra: link nao gratuito ignorado\n"; break ;;
        esac

        if ! fetch_page "$_cl" "$TMP/DUNGEON"; then
            printf "Masmorra: falha ao enviar ataque gratuito\n"
            break
        fi

        # Se a sessao caiu, nao conta ataque como executado.
        if command -v is_logged_in >/dev/null 2>&1 && ! is_logged_in "`cat "$TMP/DUNGEON" 2>/dev/null`"; then
            printf "Masmorra: sessao nao confirmada apos ataque\n"
            break
        fi

        _n=$((_n + 1))
        printf "Masmorra: ataque enviado %s/10\n" "$_n"

        if ! grep -q -E '/clandungeon/(attack|executar)' "$TMP/DUNGEON" 2>/dev/null; then
            fetch_page "/clandungeon/" "$TMP/DUNGEON" || break
        fi
        sleep 1
    done

    if [ "$_n" -gt 0 ]; then
        printf "Masmorra: %s ataque(s) gratuito(s) enviado(s)\n" "$_n"
        unset _golpes _br _cl _exec _n
        return 0
    fi

    printf "Masmorra: nenhum ataque gratuito enviado agora\n"
    unset _golpes _br _n _cl _exec
    return 1
}

clan_lider() {
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/" "$TMP/CLANPG" || return 1
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

# Temporariamente fail-closed: a estatua pode consumir recursos do cla e ainda
# nao passa pelo resource_guard. Mantemos a funcao por compatibilidade, mas nao
# executamos upgrades automaticos ate a politica economica ser explicitada.
clan_statue() {
    printf "Estatua do cla: automacao de gasto desativada por seguranca\n"
    return 1
}

clanQuests() {
    [ -n "$CLD" ] || return 1

    fetch_page "/clan/${CLD}/quest/" || return 1
    QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    CQ_BREAK=$(($(date +%s) + 90))
    while [ -n "$QUEST" ] && [ "$(date +%s)" -lt "$CQ_BREAK" ]; do
        fetch_page "$QUEST" || break
        printf "Clan quest: acao enviada\n"
        fetch_page "/clan/${CLD}/quest/" || break
        QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    done
}
