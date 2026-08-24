#!/bin/sh
# status.sh - Painel do TWM, SOMENTE LEITURA
#
# Mostra as contas sem tocar em nenhum processo: nao sobe, nao mata e nao
# relanca worker. Pode ser aberto e fechado a vontade, e sair com ctrl+c nao
# para conta nenhuma.

umask 077

# Resolve o caminho real do script, seguindo links simbolicos.
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
_dir=$(dirname "$_self")
TWMDIR=$(cd "$_dir" && pwd -P)
unset _dir _self _link _hops
export TWMDIR

STATUS_DIR="$HOME/.twm/status"

PANEL_ONCE=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -1|--once) PANEL_ONCE=1 ;;
        -n)        shift; PANEL_INTERVAL="$1" ;;
        -h|--help)
            printf "uso: ./status.sh [-1] [-n SEGUNDOS]\n"
            printf "  -1        imprime uma vez e sai\n"
            printf "  -n SEG    intervalo de atualizacao (padrao 20)\n"
            exit 0
            ;;
    esac
    shift
done
case "${PANEL_INTERVAL:-20}" in ''|*[!0-9]*) PANEL_INTERVAL=20 ;; esac
export PANEL_INTERVAL

server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

clean_field() {
    printf '%s' "$1" | tr -d '\r' | tr -d '\000-\037'
}

resolve_accounts_file() {
    if [ -s "$TWMDIR/accounts.conf" ]; then
        printf '%s' "$TWMDIR/accounts.conf"
        return 0
    fi
    for _cand in "$HOME/Furia-de-titas/accounts.conf" \
                 "$HOME/.twm/accounts.conf" \
                 "$HOME/twm/accounts.conf"; do
        if [ -s "$_cand" ]; then
            printf '%s' "$_cand"
            unset _cand
            return 0
        fi
    done
    unset _cand
    printf '%s' "$TWMDIR/accounts.conf"
}

ACCOUNTS_FILE=$(resolve_accounts_file)

if [ ! -s "$ACCOUNTS_FILE" ]; then
    printf "Nenhuma conta cadastrada em %s\n" "$ACCOUNTS_FILE"
    printf "Execute: ./setup.sh\n"
    exit 1
fi

if [ ! -d "$STATUS_DIR" ]; then
    printf "As contas nunca foram iniciadas neste aparelho (%s nao existe).\n" "$STATUS_DIR"
    printf "Execute: ./play.sh\n"
    exit 1
fi

# Somente leitura: o panel.sh nao relanca nada com PANEL_SUPERVISE=0.
PANEL_SUPERVISE=0
. "$TWMDIR/panel.sh"
# Camada LIVE: preserva o desenho e troca somente sessao/combate.
[ -f "$TWMDIR/panel_live.sh" ] && . "$TWMDIR/panel_live.sh"

if [ "$HAS_TTY" = 0 ]; then
    PANEL_ONCE=1
    PANEL_DRAW=1
fi
export PANEL_ONCE PANEL_DRAW

painel_loop
