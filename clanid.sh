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

clanDungeon() {
    if [ -z "$CLD" ]; then
        return
    fi

    printf "Clan Dungeon\n"
    fetch_page "/clan/${CLD}/dungeon/"

    DUNGEON=`grep -o -E '/clan/[0-9]+/dungeon/(fight|take)/[?]r=[0-9]+' "$TMP/SRC" | head -n1`

    if [ -n "$DUNGEON" ]; then
        fetch_page "$DUNGEON"
        printf "Clan Dungeon ok\n"
    fi
}

# Conta e lider/oficial do cla?
# A pagina do cla so mostra o link de administracao para quem tem cargo.
clan_lider() {
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/" "$TMP/CLANPG"
    grep -q -E "/clan/${CLD}/[0-9]+/adm/" "$TMP/CLANPG"
}

# Estatua do Cla: mantem os bonus ativos.
#
# A implementacao anterior usava /clan/<CLD>/statue/ e
# /statue/activate/ — URLs que nao existem no jogo. A pagina real e
# /clan/<CLD>/built/ e os bonus sao ativados por parametro:
#
#   ?privateUpgrade=true&r=N   Bonus Pessoal   (custa ouro)
#   ?goldUpgrade=true&r=N      Cla Bonus Ouro  (custa ouro do cla)
#   ?silverUpgrade=true&r=N    Cla Bonus Prata (custa prata do cla)
#
# Quando um bonus ja esta ativo o link some e a pagina mostra apenas
# "Tempo de sobra: HH:MM:SS" — por isso basta agir sobre o que aparecer.
clan_statue() {
    [ "${FUNC_clan_statue:-y}" = "y" ] || return 1
    [ -n "$CLD" ] || return 1

    # Bonus do cla so podem ser ativados por quem tem cargo.
    if ! clan_lider; then
        return 1
    fi

    fetch_page "/clan/${CLD}/built/" "$TMP/STATUE"
    [ -s "$TMP/STATUE" ] || return 1

    for _up in goldUpgrade silverUpgrade; do
        _cl=`grep -o -E "/clan/${CLD}/built/[?]${_up}=true&r=[0-9]+" "$TMP/STATUE" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl"
            case "$_up" in
                goldUpgrade)   printf "Estatua do cla: bonus de OURO ativado\n" ;;
                silverUpgrade) printf "Estatua do cla: bonus de PRATA ativado\n" ;;
            esac
        fi
    done
    unset _up _cl
    return 0
}

clanQuests() {
    if [ -z "$CLD" ]; then
        return
    fi

    fetch_page "/clan/${CLD}/quest/"

    QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`

    # Limite de tempo: se a mesma missao continuar aparecendo (por
    # exemplo uma que nao pode ser concluida), o laco nao terminava.
    CQ_BREAK=$(($(date +%s) + 90))
    while [ -n "$QUEST" ] && [ "$(date +%s)" -lt "$CQ_BREAK" ]; do
        fetch_page "$QUEST"
        printf "Clan quest processed\n"
        fetch_page "/clan/${CLD}/quest/"
        QUEST=`grep -o -E '/clan/[0-9]+/quest/(take|end)/[0-9]+/[?]r=[0-9]+' "$TMP/SRC" | head -n1`
    done
}
