#!/bin/sh
# bencao.sh - Mostra quanto tempo de bencao cada conta ainda tem
#
# A pagina /effshop/ informa o restante em "Tempo de sobra: HHHH:MM:SS", e
# o botao PROLONGA em vez de comprar: cada compra soma 3 dias ao que ja
# resta. Por isso o bot so prolonga quando falta menos de
# FUNC_blessing_min_horas (padrao 24h).
#
# Use este script para conferir o que o bot esta vendo.
#
# Uso:
#   ./bencao.sh            lista as contas
#   ./bencao.sh <numero>   mostra o estado daquela conta
#
# Apenas LE: usa o cookie que o worker ja tem, nao faz login, nao compra
# nada e nao escreve na sessao. Pode rodar com o bot ligado.

umask 077

_self="$0"
_hops=0
while [ -L "$_self" ] && [ "$_hops" -lt 20 ]; do
    _link=$(readlink "$_self")
    case "$_link" in
        /*) _self="$_link" ;;
        *)  _self="$(dirname "$_self")/$_link" ;;
    esac
    _hops=$((_hops + 1))
done
TWMDIR=$(cd "$(dirname "$_self")" && pwd -P)
unset _self _link _hops

URL="https://furiadetitas.net"

resolve_accounts_file() {
    [ -s "$TWMDIR/accounts.conf" ] && { printf '%s' "$TWMDIR/accounts.conf"; return 0; }
    for _c in "$HOME/Furia-de-titas/accounts.conf" "$HOME/.twm/accounts.conf"; do
        [ -s "$_c" ] && { printf '%s' "$_c"; return 0; }
    done
    printf '%s' "$TWMDIR/accounts.conf"
}
ACCOUNTS_FILE=$(resolve_accounts_file)

if [ ! -s "$ACCOUNTS_FILE" ]; then
    printf "Nenhuma conta cadastrada. Rode ./setup.sh\n"
    exit 1
fi

if [ -z "$1" ]; then
    printf "Contas:\n\n"
    n=1
    while IFS='|' read -r srv user _enc; do
        case "$srv" in ''|\#*) continue ;; esac
        [ -z "$user" ] && continue
        printf "  %d) %s\n" "$n" "$user"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"
    printf "\nUso: ./bencao.sh <numero>\n"
    exit 0
fi

case "$1" in *[!0-9]*) printf "Numero invalido.\n"; exit 1 ;; esac

linha=$(grep -E '^[0-9]+\|' "$ACCOUNTS_FILE" | sed -n "$1p")
[ -n "$linha" ] || { printf "Conta %s nao existe.\n" "$1"; exit 1; }
user=$(printf '%s' "$linha" | cut -d'|' -f2 | tr -d '\r')
COOKIE="$HOME/.twm/BR_${user}/cookie.txt"

if [ ! -s "$COOKIE" ]; then
    printf "A conta %s nunca logou neste aparelho — sem sessao para reusar.\n" "$user"
    printf "Inicie o bot uma vez (./play.sh) e tente de novo.\n"
    exit 1
fi

PG=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/bencao.$$")
trap 'rm -f "$PG"' EXIT INT TERM

printf "Conta: %s\n" "$user"
printf "Lendo /effshop/ com a sessao existente (sem login, sem compra)...\n\n"

# -b sem -c: le o cookie e NAO reescreve, para nao mexer na sessao do bot.
curl -sS -L --compressed --max-redirs 5 --connect-timeout 15 --max-time 30 \
     --proto '=https' --proto-redir '=https' \
     -A "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36" \
     -b "$COOKIE" "${URL}/effshop/" > "$PG" 2>/dev/null

if [ ! -s "$PG" ]; then
    printf "A pagina veio vazia — sem rede, ou a sessao expirou.\n"
    exit 1
fi

if grep -qiE "name=['\"]?pass['\"]?|action=[^>]*sign_in" "$PG"; then
    printf "Caiu na tela de login: a sessao desta conta expirou.\n"
    printf "Deixe o bot rodar um ciclo para reconectar e tente de novo.\n"
    exit 1
fi

L="------------------------------------------------------------"

printf "%s\n1. TEMPO DE BENCAO RESTANTE\n%s\n" "$L" "$L"
_r=$(sed 's/<[^>]*>/ /g' "$PG" \
     | grep -o -E "Tempo de sobra:[^0-9]{0,8}[0-9]{1,6}:[0-9]{2}:[0-9]{2}" \
     | grep -o -E '[0-9]{1,6}:[0-9]{2}:[0-9]{2}' | head -n1)
if [ -n "$_r" ]; then
    _hh=${_r%%:*}
    printf "  %s  (%s horas = %s dias)\n" "$_r" "$_hh" "$((_hh / 24))"
    if [ "$_hh" -ge "${FUNC_blessing_min_horas:-24}" ]; then
        printf "  o bot NAO prolonga: ainda ha folga\n"
    else
        printf "  o bot PROLONGA na proxima passagem\n"
    fi
else
    printf "  campo \"Tempo de sobra\" nao encontrado\n"
    printf "  o bot nao prolonga sem esse campo — me mande a secao 3\n"
fi

printf "\n%s\n1b. LINK DE PROLONGAR\n%s\n" "$L" "$L"
if grep -q "/effshop/blessing/" "$PG"; then
    printf "  presente (fica sempre na pagina, ativa ou nao)\n"
else
    printf "  ausente\n"
fi

printf "\n%s\n2. TODOS OS LINKS DA LOJA\n%s\n" "$L" "$L"
grep -o -E "/effshop/[a-zA-Z0-9_/]*[?]?[a-z]*=?[0-9]*" "$PG" | sort -u | sed 's/^/  /'

printf "\n%s\n3. TEXTO DA PAGINA (sem tags)\n%s\n" "$L" "$L"
# O saldo e trocado por [saldo] para nao expor numero da conta em print.
sed 's/<br[^>]*>/\n/g; s/<\/div>/\n/g; s/<\/tr>/\n/g; s/<[^>]*>/ /g' "$PG" \
  | sed 's/[[:space:]]\{2,\}/ /g; s/^ //; s/ $//' \
  | grep -v '^$' \
  | grep -iE "bencao|benção|blessing|ativ|expir|restan|dura|dia|hora|min|:[0-9][0-9]|efeito|bonus|comprar|adquirir" \
  | head -40 | sed 's/^/  /'

printf "\n%s\n4. CONTADORES DE TEMPO NA PAGINA\n%s\n" "$L" "$L"
sed 's/<[^>]*>/ /g' "$PG" | grep -o -E '[0-9]{1,3}:[0-9]{2}(:[0-9]{2})?' | sort -u | sed 's/^/  /'
[ -z "$(sed 's/<[^>]*>/ /g' "$PG" | grep -o -E '[0-9]{1,3}:[0-9]{2}')" ] && printf "  (nenhum)\n"

printf "\n%s\n5. CLASSES E ATRIBUTOS PERTO DA BENCAO\n%s\n" "$L" "$L"
grep -o -E ".{220}/effshop/blessing/.{220}" "$PG" \
  | sed 's/></>\n</g' | grep -iE "class=|title=|alt=|disabled|active" \
  | head -20 | sed 's/^/  /'
[ -z "$(grep -o '/effshop/blessing/' "$PG")" ] && printf "  (link ausente — nada ao redor para mostrar)\n"

printf "\n%s\n" "$L"
printf "Se algo aqui nao bater com o jogo, mande as secoes 1 a 5.\n"
printf "Nenhuma senha aparece aqui; confira antes de enviar.\n"
