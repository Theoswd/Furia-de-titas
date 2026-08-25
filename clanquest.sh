# clanquest.sh - Missoes do Cla e combinacao com as atividades
#
# Mapeamento confirmado no jogo:
#   1 Gladiador                    -> liga
#   2 Gladiador Lendario           -> liga
#   3 Guerreiro da Arena           -> arena
#   4 Guerreiro Lendario da Arena  -> arena
#   5 Procura por Recursos         -> caverna
#   6 Mestre dos torneios          -> carreira
#   7 Alquimista                   -> elixir
#   8 Velho Lojista                -> loja

cq_ids() {
    case "$1" in
        liga)     echo "1 2" ;;
        arena)    echo "3 4" ;;
        caverna)  echo "5" ;;
        carreira) echo "6" ;;
        elixir)   echo "7" ;;
        loja)     echo "8" ;;
        *)        echo "" ;;
    esac
}

cq_pagina() {
    [ -n "$CLD" ] || clan_id
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/quest/" "$TMP/CQUEST" || return 1
    [ -s "$TMP/CQUEST" ]
}

cq_tomar() {
    _tipo="$1"
    [ "${FUNC_clan_quests:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _tomou=1
    for _id in `cq_ids "$_tipo"`; do
        _cl=`grep -o -E "/clan/${CLD}/quest/take/${_id}/[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            if fetch_page "$_cl"; then
                printf "Missao do cla: tomada (%s #%s)\n" "$_tipo" "$_id"
                _tomou=0
            fi
            break
        fi
    done
    unset _tipo _id _cl
    return $_tomou
}

cq_concluir() {
    [ "${FUNC_clan_quests:-y}" = "y" ] || return 1
    cq_pagina || return 1
    _n=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/end/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            if fetch_page "$_cl"; then
                printf "Missao do cla #%s: coleta enviada\n" "$_id"
                _n=$((_n + 1))
                cq_pagina >/dev/null 2>&1 || break
            fi
        fi
    done
    unset _id _cl
    [ "$_n" -gt 0 ]
}

# Retorna 0 apenas se o contexto do link NAO apresentar indicio de custo em
# ouro. E fail-closed: se nao for possivel localizar o link no HTML, nega.
cq_help_sem_ouro() {
    _href="$1"
    _ctx=`awk -v needle="$_href" '
        {
            p=index($0, needle)
            if (p > 0) {
                s=p-160; if (s < 1) s=1
                print substr($0, s, length(needle)+320)
                exit
            }
        }
    ' "$TMP/CQUEST" 2>/dev/null`

    [ -n "$_ctx" ] || { unset _href _ctx; return 1; }
    if printf '%s' "$_ctx" | grep -qiE 'gold\.png|gold|ouro|pagar|comprar|pay|buy'; then
        unset _href _ctx
        return 1
    fi
    unset _href _ctx
    return 0
}

# Ajuda companheiros SEM GASTAR OURO. O link legado /help nunca e seguido por
# checkQuest(); toda ajuda passa por esta funcao e pelo contexto do HTML.
cq_ajudar() {
    [ "${FUNC_clan_help:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _n=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/help/${_id}/?[?]r=[0-9]+[^\"' <]*" "$TMP/CQUEST" | sed -n 1p`
        [ -n "$_cl" ] || continue

        if ! cq_help_sem_ouro "$_cl"; then
            printf "Ajuda do cla ignorada por seguranca/custo (#%s)\n" "$_id"
            continue
        fi

        if fetch_page "$_cl"; then
            printf "Ajuda do cla sem indicador de ouro: enviada (#%s)\n" "$_id"
            _n=$((_n + 1))
            cq_pagina >/dev/null 2>&1 || break
        fi
    done
    unset _id _cl
    [ "$_n" -gt 0 ]
}

# Compatibilidade: conclusao forcada com ouro permanece bloqueada por default
# e tambem e forcada para n em function.sh/priority.sh.
cq_forcar_ouro() {
    [ "${FUNC_quest_force_gold:-n}" = "y" ] || return 1
    return 1
}

cq_antes() {
    [ -n "$CLD" ] || return 1
    cq_concluir > /dev/null 2>&1
    cq_tomar "$1"
}
