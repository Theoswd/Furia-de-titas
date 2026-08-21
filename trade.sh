# Troca PRATA -> OURO.
#
# A implementacao anterior procurava /trade/exchange/silver/N, que e o
# sentido contrario (comprar prata com ouro). A pagina do jogo oferece:
#   /trade/exchange/gold/1?r=N     1800 prata  ->   1 ouro
#   /trade/exchange/gold/10?r=N   18000 prata  ->  10 ouro
#   /trade/exchange/gold/100?r=N 180000 prata  -> 100 ouro
# Compra sempre pelo maior lote disponivel, que e a taxa mais eficiente.
# Troca PRATA -> OURO, com o lote escolhido pelo saldo da conta.
#
# A pagina oferece tres lotes:
#   /trade/exchange/gold/1?r=N       1800 prata ->   1 ouro
#   /trade/exchange/gold/10?r=N     18000 prata ->  10 ouro
#   /trade/exchange/gold/100?r=N   180000 prata -> 100 ouro
#
# Criterio: so usa um lote se a prata em caixa sustentar essa troca todo
# dia por um ano (365 vezes). Assim a troca nunca compromete a economia
# da conta — quem tem pouca prata cai para o lote menor em vez de parar.
#
#   lote 100 -> precisa de  65.700.000 de prata
#   lote  10 -> precisa de   6.570.000
#   lote   1 -> precisa de     657.000
#   abaixo disso nao troca
# Troca PRATA -> OURO, UMA VEZ POR DIA.
#
# A pagina oferece tres lotes:
#   /trade/exchange/gold/1?r=N       1800 prata ->   1 ouro
#   /trade/exchange/gold/10?r=N     18000 prata ->  10 ouro
#   /trade/exchange/gold/100?r=N   180000 prata -> 100 ouro
#
# O lote e escolhido pela reserva de prata: so usa um lote se o saldo
# aguentar essa mesma troca, uma por dia, durante um ano inteiro. Isso
# mantem a economia estavel — quem tem pouca prata cai para o lote menor
# em vez de drenar o caixa.
#
#   lote 100 -> reserva de 65.700.000 de prata (365 x 180.000)
#   lote  10 -> reserva de  6.570.000
#   lote   1 -> reserva de    657.000
#   abaixo disso nao troca
#
# A troca ocorre UMA VEZ por dia. O marcador fica em $TMP/last_trade e
# guarda a data, entao reiniciar o bot no mesmo dia nao repete a troca.
func_trade() {
    [ "${FUNC_trade:-y}" = "y" ] || return 1

    _hoje=`date +%Y%m%d`
    _ult=`cat "$TMP/last_trade" 2>/dev/null`
    if [ "$_ult" = "$_hoje" ]; then
        unset _hoje _ult
        return 0
    fi

    printf "Trade\n"

    _dias=${FUNC_trade_dias:-365}
    case "$_dias" in ''|*[!0-9]*) _dias=365 ;; esac

    fetch_page "/trade/exchange"
    # Saldo da conta e sempre alt='s'; alt='' e taxa de cambio da propria loja.
    _pr=`grep -o -E "silver\.png' alt='s'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/SRC" | sed -E "s@.*/> ?@@" | head -n1`
    _prata=`valor_num "$_pr"`
    case "$_prata" in ''|*[!0-9]*) _prata=0 ;; esac

    if   [ "$_prata" -ge $((180000 * _dias)) ]; then _lote=100
    elif [ "$_prata" -ge $((18000  * _dias)) ]; then _lote=10
    elif [ "$_prata" -ge $((1800   * _dias)) ]; then _lote=1
    else
        printf "Trade: prata insuficiente para trocar com seguranca (%s)\n" "$_pr"
        printf "Trade ok\n"
        unset _hoje _ult _dias _pr _prata _lote
        return 0
    fi

    _cl=`grep -o -E "/trade/exchange/gold/${_lote}[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    if [ -z "$_cl" ]; then
        printf "Trade: lote de %s indisponivel agora\n" "$_lote"
        printf "Trade ok\n"
        unset _hoje _ult _dias _pr _prata _lote _cl
        return 0
    fi

    fetch_page "$_cl"
    printf '%s' "$_hoje" > "$TMP/last_trade" 2>/dev/null
    printf "Trade: prata %s — trocou por %s de ouro (1x hoje)\n" "$_pr" "$_lote"
    printf "Trade ok\n"
    unset _hoje _ult _dias _pr _prata _lote _cl
}

# Compra a Bencao em /effshop/ (+200 em todas as estatisticas, +25%% de
# experiencia, 100 ouro, dura 3 dias). Se ja estiver ativa o link nao
# aparece na pagina, entao basta agir sobre o que existir.
# Bencao dos Deuses: +200 em todas as estatisticas e +25% de experiencia.
#
# A REGRA, lida da propria pagina /effshop/:
#
#     Tempo de sobra: 1331:22:39
#     [ Prolongar para 100 ouro ]
#     Duracao - 3 dias
#
# Dois fatos que mudam tudo:
#
#   1. A pagina DIZ quanto falta, em "Tempo de sobra: HHHH:MM:SS". Nao e
#      preciso adivinhar pelo link nem confiar em marcador local — o
#      estado vem do servidor, que e quem manda.
#
#   2. O botao diz PROLONGAR, nao comprar. A compra ACUMULA em cima do
#      que ja resta, e o link fica sempre na pagina. Por isso o criterio
#      antigo ("o link sumiu, entao esta ativa") nunca poderia funcionar:
#      o link nao some nunca.
#
# A conta inspecionada estava com 1331 horas de bencao — 55 dias, cerca de
# 18 compras de 3 dias empilhadas, quase 1.800 de ouro gastos em cima de
# uma bencao que ja estava valendo. Era o bot prolongando a cada ciclo.
#
# Agora so prolonga quando falta pouco (FUNC_blessing_min_horas, padrao
# 24h). Se a pagina mudar e o "Tempo de sobra" nao for encontrado, NAO
# compra: sem saber o estado, ficar quieto e mais barato que gastar.
use_blessing() {
    [ "${FUNC_use_blessing:-y}" = "y" ] || return 1

    # Portao curto so para nao reabrir a loja a cada ciclo. Quem decide de
    # verdade e o "Tempo de sobra" lido abaixo.
    bencao_liberada || return 1

    fetch_page "/effshop/" "$TMP/EFFSHOP"
    [ -s "$TMP/EFFSHOP" ] || return 1

    # "Tempo de sobra: 1331:22:39" -> 1331 (horas restantes).
    # O campo das horas nao tem limite de dois digitos: 55 dias viram 1331.
    _resto=`sed 's/<[^>]*>/ /g' "$TMP/EFFSHOP" \
        | grep -o -E "Tempo de sobra:[^0-9]{0,8}[0-9]{1,6}:[0-9]{2}:[0-9]{2}" \
        | grep -o -E '[0-9]{1,6}:[0-9]{2}:[0-9]{2}' | head -n1`
    _horas=${_resto%%:*}
    case "$_horas" in ''|*[!0-9]*) _horas="" ;; esac

    _min=${FUNC_blessing_min_horas:-24}
    case "$_min" in ''|*[!0-9]*) _min=24 ;; esac

    if [ -z "$_horas" ]; then
        # Sem o campo na pagina nao da para saber o estado. Nao compra:
        # prolongar as cegas foi exatamente o que empilhou 55 dias.
        bencao_adiar 12
        printf "Bencao: \"Tempo de sobra\" nao encontrado na pagina — nao prolonga\n"
        printf "bencao: campo Tempo de sobra ausente em /effshop/\n" >> "$TMP/ERROR_DEBUG"
        unset _resto _horas _min
        return 1
    fi

    if [ "$_horas" -ge "$_min" ]; then
        # Reavalia quando estiver perto do minimo, com teto de 24h para o
        # caso de 1300 horas restantes.
        _adia=$(( _horas - _min ))
        [ "$_adia" -gt 24 ] && _adia=24
        [ "$_adia" -lt 1 ]  && _adia=1
        bencao_adiar "$_adia"
        printf "Bencao ativa: %sh restantes (minimo %sh) — nao prolonga\n" "$_horas" "$_min"
        unset _resto _horas _min _adia
        return 0
    fi

    _cl=`grep -o -E "/effshop/blessing/[?]r=[0-9]+" "$TMP/EFFSHOP" | sed -n 1p`
    if [ -z "$_cl" ]; then
        bencao_adiar 6
        printf "Bencao: %sh restantes, mas sem link para prolongar\n" "$_horas"
        unset _resto _horas _min _cl
        return 1
    fi

    # Saldo da conta e sempre alt='g'; alt='' e o preco do item.
    _ouro=`grep -o -E "gold\.png' alt='g'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/EFFSHOP" | sed -E "s@.*/> ?@@" | head -n1`
    _ouro=`valor_num "$_ouro"`
    case "$_ouro" in ''|*[!0-9]*) _ouro=0 ;; esac
    if [ "$_ouro" -lt "${FUNC_blessing_gold_min:-100}" ]; then
        bencao_adiar 6
        printf "Bencao: %sh restantes, ouro insuficiente (%s)\n" "$_horas" "$_ouro"
        unset _resto _horas _min _cl _ouro
        return 1
    fi

    fetch_page "$_cl"
    bencao_marcar
    printf "Bencao prolongada por 3 dias (restavam %sh, ouro %s)\n" "$_horas" "$_ouro"
    unset _resto _horas _min _cl _ouro
    return 0
}

clan_money() {
    clan_id
    if [ -n "$CLD" ]; then
        printf "Clan money ...\n"

        fetch_page "/arena/quit"
        awk_code=`sed "s/href='/\n/g" "$TMP/SRC" | grep "attack/1" | head -n 1 | awk -F\/ '{ print $5 }' | tr -cd '[:digit:]'`
        echo "$awk_code" > "$TMP/CODE"

        printf "/clan/%s/money/?r=%s&silver=1000&gold=0&confirm=true&type=limit\n" "$CLD" "`cat "$TMP/CODE"`"
        fetch_page "/clan/${CLD}/money/?r=$(cat "$TMP/CODE")&silver=1000&gold=0&confirm=true&type=limit"

        fetch_page "/arena/quit"
        awk_code=`sed "s/href='/\n/g" "$TMP/SRC" | grep "attack/1" | head -n 1 | awk -F\/ '{ print $5 }' | tr -cd '[:digit:]'`
        echo "$awk_code" > "$TMP/CODE"

        printf "/clan/%s/money/?r=%s&silver=1000&gold=0&confirm=true&type=limit\n" "$CLD" "`cat "$TMP/CODE"`"
        fetch_page "/clan/${CLD}/money/?r=$(cat "$TMP/CODE")&silver=1000&gold=0&confirm=true&type=limit"

        printf "Clan money ok\n"
    fi
}
