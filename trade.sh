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

    fetch_page "/trade/exchange" || return 1
    _pr=`grep -o -E "silver\.png' alt='s'/> ?[0-9][0-9.,']{0,14}[KMBkmb]?" "$TMP/SRC" | sed -E "s@.*/> ?@@" | head -n1`
    _prata=`valor_num "$_pr"`
    case "$_prata" in ''|*[!0-9]*) _prata=0 ;; esac

    if   [ "$_prata" -ge $((180000 * _dias)) ]; then _lote=100
    elif [ "$_prata" -ge $((18000  * _dias)) ]; then _lote=10
    elif [ "$_prata" -ge $((1800   * _dias)) ]; then _lote=1
    else
        printf "Trade: prata insuficiente para trocar com seguranca (%s)\n" "$_pr"
        unset _hoje _ult _dias _pr _prata _lote
        return 3
    fi

    _cl=`grep -o -E "/trade/exchange/gold/${_lote}[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    if [ -z "$_cl" ]; then
        printf "Trade: lote de %s indisponivel agora\n" "$_lote"
        unset _hoje _ult _dias _pr _prata _lote _cl
        return 3
    fi

    if ! fetch_page "$_cl"; then
        unset _hoje _ult _dias _pr _prata _lote _cl
        return 1
    fi

    if command -v is_logged_in >/dev/null 2>&1; then
        _trade_page=`cat "$TMP/SRC" 2>/dev/null`
        if ! is_logged_in "$_trade_page"; then
            printf "Trade: sessao perdida; troca nao contabilizada\n"
            unset _hoje _ult _dias _pr _prata _lote _cl _trade_page
            return 1
        fi
        unset _trade_page
    fi

    # O marcador indica que a ACAO foi enviada uma vez hoje. A confirmacao
    # economica saldo-antes/saldo-depois ainda sera implementada separadamente.
    printf '%s' "$_hoje" > "$TMP/last_trade" 2>/dev/null
    printf "Trade: pedido de troca por %s ouro enviado (1x hoje)\n" "$_lote"
    unset _hoje _ult _dias _pr _prata _lote _cl
    return 0
}

# BENCAO DESATIVADA POR COMPLETO.
use_blessing() {
    return 0
}

# Tesouraria do cla temporariamente desativada.
# A implementacao antiga enviava prata=1000 duas vezes e ouro=0, sem seguir
# a politica definida para ouro diario, prata em dias alternados e deduplicacao.
# Fail-closed e preferivel a registrar uma doacao incorreta como sucesso.
clan_money() {
    printf "Tesouraria do cla: automacao desativada ate a politica V2.1 ser validada\n"
    return 1
}
