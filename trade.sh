# Troca PRATA -> OURO.
#
# A pagina oferece tres lotes:
#   /trade/exchange/gold/1?r=N       1800 prata ->   1 ouro
#   /trade/exchange/gold/10?r=N     18000 prata ->  10 ouro
#   /trade/exchange/gold/100?r=N   180000 prata -> 100 ouro
#
# A troca ocorre UMA VEZ por dia. O lote e escolhido pela reserva de prata.
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

# BÊNÇÃO DESATIVADA POR COMPLETO.
# Mantemos o nome da funcao para compatibilidade com codigo antigo, mas ela
# nunca consulta /effshop, nunca segue /effshop/blessing e nunca gasta ouro.
use_blessing() {
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
