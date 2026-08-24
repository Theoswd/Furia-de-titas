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
    fetch_page "/clan/${CLD}/quest/" "$TMP/CQUEST"
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
            fetch_page "$_cl"
            printf "Missao do cla tomada (%s #%s)\n" "$_tipo" "$_id"
            _tomou=0
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
            fetch_page "$_cl"
            printf "Missao do cla concluida (#%s)\n" "$_id"
            _n=$((_n + 1))
        fi
    done
    unset _id _cl
    [ "$_n" -gt 0 ]
}

# Ajuda companheiros SEM GASTAR OURO.
# Qualquer link identificado como pago e ignorado; nao existe excecao de
# "uma vez por ciclo". Esta regra e absoluta no agente de prioridade.
cq_ajudar() {
    [ "${FUNC_clan_help:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _n=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/help/${_id}/?[?]r=[0-9]+[^\"' <]*" "$TMP/CQUEST" | sed -n 1p`
        [ -n "$_cl" ] || continue

        # Nunca seguir links pagos.
        if printf '%s' "$_cl" | grep -qiE 'gold|pay|buy|confirm'; then
            printf "Ajuda paga ignorada (#%s)\n" "$_id"
            continue
        fi

        fetch_page "$_cl"
        printf "Ajuda gratuita em missao do cla (#%s)\n" "$_id"
        _n=$((_n + 1))
    done
    unset _id _cl
    [ "$_n" -gt 0 ]
}

# Mantido por compatibilidade, mas o scheduler de prioridade NAO chama esta
# funcao automaticamente. Qualquer uso de ouro para concluir missao exige um
# fluxo explicitamente habilitado fora do agente atual.
cq_forcar_ouro() {
    [ "${FUNC_quest_force_gold:-n}" = "y" ] || return 1
    _min=${FUNC_quest_gold_min:-1200}
    case "$_min" in ''|*[!0-9]*) _min=1200 ;; esac

    cq_pagina || return 1
    _ouro=`grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/CQUEST" | sed -E "s@.*/> ?@@" | head -n1`
    _ouro=`valor_num "$_ouro"`
    case "$_ouro" in ''|*[!0-9]*) return 1 ;; esac
    [ "$_ouro" -gt "$_min" ] || return 1

    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/(finish|complete|endGold|forGold)/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        if [ -n "$_cl" ]; then
            fetch_page "$_cl"
            printf "Missao do cla concluida com ouro (#%s, ouro %s)\n" "$_id" "$_ouro"
            unset _id _cl _ouro _min
            return 0
        fi
    done
    unset _id _cl _ouro _min
    return 1
}

cq_antes() {
    [ -n "$CLD" ] || return 1
    cq_concluir > /dev/null 2>&1
    cq_tomar "$1"
}
