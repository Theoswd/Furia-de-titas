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

# Baixa a pagina de missoes do cla em $TMP/CQUEST, reaproveitando por
# alguns segundos.
#
# CORRECAO (15 downloads da MESMA pagina por ciclo): toda funcao daqui
# comeca chamando cq_pagina, e um ciclo de start() as encadeia:
#
#   cq_concluir 1 + cq_ajudar 1 + cq_forcar_ouro 1
#   + cq_antes x6, e cada cq_antes faz cq_concluir + cq_tomar   = 12
#   ------------------------------------------------------------
#                                                              = 15
#
# Quinze vezes a mesma pagina, por conta, por ciclo — com 6 contas sao 90
# requisicoes por ciclo que nao acrescentam nada. A pagina so muda quando o
# proprio bot age sobre ela (tomar, concluir, ajudar), e esses pontos
# invalidam o cache explicitamente, entao a leitura nunca fica velha.
cq_pagina() {
    [ -n "$CLD" ] || clan_id
    [ -n "$CLD" ] || return 1

    if [ -s "$TMP/CQUEST" ]; then
        _cq_mt=`stat -c %Y "$TMP/CQUEST" 2>/dev/null`
        case "$_cq_mt" in
            ''|*[!0-9]*) ;;   # sem stat utilizavel: baixa de novo
            *)
                _cq_idade=$(( `date +%s` - _cq_mt ))
                if [ "$_cq_idade" -ge 0 ] && [ "$_cq_idade" -lt "${CQ_TTL:-45}" ]; then
                    unset _cq_mt _cq_idade
                    return 0
                fi
                ;;
        esac
        unset _cq_mt _cq_idade
    fi

    fetch_page "/clan/${CLD}/quest/" "$TMP/CQUEST"
    [ -s "$TMP/CQUEST" ]
}

# Descarta o cache. Chamado depois de toda acao que muda a pagina.
cq_invalidar() { rm -f "$TMP/CQUEST" 2>/dev/null; return 0; }

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
    # DEPOIS do laco, nunca dentro: o cache e a propria lista que o laco
    # esta percorrendo. Invalidando a cada volta, a missao 1 era tomada,
    # a pagina sumia e a 2 nao era mais encontrada — "liga" e "arena" tem
    # duas missoes cada, e a segunda de cada par ficava para tras.
    [ "$_tomou" = 0 ] && cq_invalidar
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
    [ "$_n" -gt 0 ] && cq_invalidar
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
    _ajudou=0
    for _id in 1 2 3 4 5 6 7 8; do
        _cl=`grep -o -E "/clan/${CLD}/quest/help/${_id}/?[?]r=[0-9]+" "$TMP/CQUEST" | sed -n 1p`
        [ -n "$_cl" ] || continue

        # CORRECAO: aqui o teste era
        #     printf '%s' "$_cl" | grep -q 'gold\|pay'
        # sobre a URL de ajuda — que e sempre
        #     /clan/<CLD>/quest/help/<id>/?r=<numero>
        # e portanto NUNCA contem "gold" nem "pay". O limite de uma ajuda
        # paga por ciclo, que o comentario prometia, nunca entrou em vigor:
        # o grep dava falso em todas as voltas.
        #
        # O custo, quando existe, esta no TEXTO da pagina ao lado do link,
        # nao na URL. Sem uma ancora confiavel para esse texto, o limite
        # passa a valer para QUALQUER ajuda: no maximo uma por ciclo. Ajudar
        # menos e recuperavel — o proximo ciclo ajuda de novo; gastar ouro
        # sem querer, nao.
        [ "$_usou_ouro" -eq 1 ] && continue
        _usou_ouro=1
        fetch_page "$_cl"
        printf "Ajuda em missao do cla (#%s)\n" "$_id"
        _ajudou=1
    done
    [ "${_ajudou:-0}" = 1 ] && cq_invalidar
    unset _id _cl _usou_ouro _ajudou
    return 0
}

# cq_forcar_ouro
# Missao parada com ouro suficiente: conclui pagando.
# O limite vem de FUNC_quest_gold_min (padrao 1200).
#
# DESLIGADA POR PADRAO — a mecanica nao existe neste jogo.
#
# Os nomes de URL abaixo (finish, complete, endGold, forGold) eram chutes:
# nenhum deles aparece na pagina de missoes do cla. A pagina real foi
# inspecionada em duas contas, uma delas com 4.620 de ouro, e nao ha link,
# nem onclick, nem form, nem button de concluir-missao-com-ouro. O que a
# pagina oferece e tomar, cancelar, ajudar e concluir quando o progresso
# fecha — nada pago.
#
# Ligada, a funcao so gastava uma leitura de pagina por ciclo para procurar
# um link que nunca existiu. Fica no codigo, e nao removida, para o caso de
# o jogo passar a oferecer: quem quiser tentar usa FUNC_quest_force_gold=y
# e confere o log.
cq_forcar_ouro() {
    [ "${FUNC_quest_force_gold:-n}" = "y" ] || return 1
    _min=${FUNC_quest_gold_min:-1200}
    case "$_min" in ''|*[!0-9]*) _min=1200 ;; esac

    # Ouro atual, lido da propria pagina
    cq_pagina || return 1
    # Saldo da conta e sempre alt='g'; alt='Ouro' e a recompensa da missao.
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

# cq_antes <tipo>
# Chamada antes de cada atividade: recolhe concluidas, toma a do tipo,
# e devolve 0 se a atividade esta combinada com alguma missao.
cq_antes() {
    [ -n "$CLD" ] || return 1
    cq_concluir > /dev/null 2>&1
    cq_tomar "$1"
}
