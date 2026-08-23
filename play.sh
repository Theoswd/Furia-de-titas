# ============================================================
#  PAINEL
#  Mora no panel.sh, compartilhado com o status.sh. Aqui ele
#  roda em modo supervisor: relanca worker que morrer.
# ============================================================
. "$TWMDIR/panel.sh"
# Camada somente de exibicao: preserva o layout do panel.sh e troca apenas
# a funcao de sessao pelo caminho real da conta.
[ -f "$TWMDIR/panel_live.sh" ] && . "$TWMDIR/panel_live.sh"
PANEL_SUPERVISE=1
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s); painel oculto (sem terminal)"
painel_loop
