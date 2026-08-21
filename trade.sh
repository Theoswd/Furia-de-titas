# Troca PRATA -> OURO.
#
# A implementacao anterior procurava /trade/exchange/silver/N, que e o
# sentido contrario (comprar prata com ouro). A pagina do jogo oferece:
#   /trade/exchange/gold/1?r=N     1800 prata  ->   1 ouro
#   /trade/exchange/gold/10?r=N   18000 prata  ->  10 ouro
#   /trade/exchange/gold/100?r=N 180000 prata  -> 100 ouro
# Compra sempre pelo maior lote disponivel, que e a taxa mais eficiente.
func_trade() {
    [ "${FUNC_trade:-y}" = "y" ] || return 1
    printf "Trade\n"

    _br=$(($(date +%s) + 60))
    _feito=0

    while [ "$(date +%s)" -lt "$_br" ]; do
        fetch_page "/trade/exchange"
        _cl=""
        for _lote in 100 10 1; do
            _cl=`grep -o -E "/trade/exchange/gold/${_lote}[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
            [ -n "$_cl" ] && break
        done
        [ -n "$_cl" ] || break

        fetch_page "$_cl"
        printf "Trocou prata por %s ouro\n" "$_lote"
        _feito=$((_feito + _lote))
    done

    [ "$_feito" -gt 0 ] && printf "Trade: %s ouro obtido\n" "$_feito"
    printf "Trade ok\n"
    unset _br _cl _lote _feito
}

# Compra a Bencao em /effshop/ (+200 em todas as estatisticas, +25%% de
# experiencia, 100 ouro, dura 3 dias). Se ja estiver ativa o link nao
# aparece na pagina, entao basta agir sobre o que existir.
use_blessing() {
    [ "${FUNC_use_blessing:-y}" = "y" ] || return 1

    fetch_page "/effshop/" "$TMP/EFFSHOP"
    [ -s "$TMP/EFFSHOP" ] || return 1

    _cl=`grep -o -E "/effshop/blessing/[?]r=[0-9]+" "$TMP/EFFSHOP" | sed -n 1p`
    if [ -z "$_cl" ]; then
        unset _cl
        return 1
    fi

    # So compra se houver ouro suficiente (custa 100).
    _ouro=`grep -o -E "gold\.png' alt='[^']*'/> ?[0-9][0-9.,]{0,12}" "$TMP/EFFSHOP" | sed -E "s@.*/> ?@@" | head -n1 | tr -d '.,'`
    case "$_ouro" in ''|*[!0-9]*) _ouro=0 ;; esac
    if [ "$_ouro" -lt "${FUNC_blessing_gold_min:-100}" ]; then
        printf "Bencao: ouro insuficiente (%s)\n" "$_ouro"
        unset _cl _ouro
        return 1
    fi

    fetch_page "$_cl"
    printf "Bencao comprada (%s ouro disponiveis)\n" "$_ouro"
    unset _cl _ouro
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
