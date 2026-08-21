# clanquest.sh - Missoes do Cla e combinacao com as atividades
#
# A pagina /clan/<CLD>/quest/ lista 8 missoes, cada uma ligada a uma
# atividade. Mapeamento confirmado no jogo:
#
#   1 Gladiador                    Lute na Arena 20x na Liga     -> liga
#   2 Gladiador Lendario           Vença 15x na Liga             -> liga
#   3 Guerreiro da Arena           Lute 75x na Arena             -> arena
#   4 Guerreiro Lendario da Arena  Vença 50x na Arena            -> arena
#   5 Procura por Recursos         Faça 8 pesquisas na Caverna   -> caverna
#   6 Mestre dos torneios          Participe de 6 torneios       -> carreira
#   7 Alquimista                   Faça 2 Elixires               -> elixir
#   8 Velho Lojista                Obtenha 3 pedras ou ervas     -> loja
#
# A ideia e sempre TOMAR a missao antes de executar a atividade, para que
# o progresso conte. Fazer a atividade sem a missao ativa desperdiça a
# tentativa.

# IDs de missao por tipo de atividade
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

# Baixa a pagina de missoes do cla em $TMP/CQUEST.
cq_pagina() {
    [ -n "$CLD" ] || clan_id
    [ -n "$CLD" ] || return 1
    fetch_page "/clan/${CLD}/quest/" "$TMP/CQUEST"
    [ -s "$TMP/CQUEST" ]
}

# cq_tomar <tipo>
# Toma a missao do cla correspondente aquela atividade, se houver.
# Devolve 0 se tomou alguma (a atividade vale a pena agora).
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
        fi
    done
    unset _tipo _id _cl
    return $_tomou
}

# cq_concluir
# Recolhe as missoes ja concluidas.
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

# cq_ajudar
# Apoia missoes de companheiros que estejam perto de concluir.
# O gasto de ouro em ajuda e limitado a UMA vez por ciclo.
cq_ajudar() {
    [ "${FUNC_clan_help:-y}" = "y" ] || return 1
    cq_pagina || return 1

    _usou_ouro=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/help/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        [ -n "$_cl" ] || continue

        # Links de ajuda que cobram ouro trazem confirmacao de custo.
        if printf '%s' "$_cl" | grep -q 'gold\|pay'; then
            [ "$_usou_ouro" -eq 1 ] && continue
            _usou_ouro=1
        fi
        fetch_page "$_cl"
        printf "Ajuda em missao do cla (#%s)\n" "$_id"
    done
    unset _id _cl _usou_ouro
    return 0
}

# cq_forcar_ouro
# Missao parada com ouro suficiente: conclui pagando.
# O limite vem de FUNC_quest_gold_min (padrao 1200).
cq_forcar_ouro() {
    [ "${FUNC_quest_force_gold:-y}" = "y" ] || return 1
    _min=${FUNC_quest_gold_min:-1200}
    case "$_min" in ''|*[!0-9]*) _min=1200 ;; esac

    # Ouro atual, lido da propria pagina
    cq_pagina || return 1
    _ouro=`grep -o -E "gold\.png. alt=.[^']*./> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/CQUEST" | sed -E "s@.*/> ?@@" | head -n1`
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

# cq_antes <tipo>
# Chamada antes de cada atividade: recolhe concluidas, toma a do tipo,
# e devolve 0 se a atividade esta combinada com alguma missao.
cq_antes() {
    [ -n "$CLD" ] || return 1
    cq_concluir > /dev/null 2>&1
    cq_tomar "$1"
}
