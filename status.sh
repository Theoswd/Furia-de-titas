# Somente leitura: o panel.sh nao relanca nada com PANEL_SUPERVISE=0.
PANEL_SUPERVISE=0
. "$TWMDIR/panel.sh"
# Mesma camada de exibicao do play.sh: nao altera o layout, apenas mostra
# a sessao/pagina real registrada pela conta.
[ -f "$TWMDIR/panel_live.sh" ] && . "$TWMDIR/panel_live.sh"

# Sem terminal (redirecionado para arquivo, pipe, etc.) o painel nao imprime
# nada — imprimir a cada 20s num arquivo so geraria lixo. Nesse caso o modo
# de uma volta e o unico que faz sentido.
if [ "$HAS_TTY" = 0 ]; then
    PANEL_ONCE=1
    PANEL_DRAW=1
fi
export PANEL_ONCE PANEL_DRAW

painel_loop
