#!/bin/sh
# play.sh - Orquestrador multi-contas TWM
#
# A branch tinha recebido somente o trecho final do painel. Isso removia a
# inicializacao do orquestrador, incluindo TWMDIR, contas e workers.
# Mantemos o play.sh funcional do commit-base e aplicamos somente o painel
# da feature no final.

TWMDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export TWMDIR

_RUNTIME="$TWMDIR/.play.runtime.$$"
_cleanup() {
    rm -f "$_RUNTIME"
}
trap _cleanup EXIT INT TERM HUP

if ! git -C "$TWMDIR" show f6d7c6b:play.sh > "$_RUNTIME" 2>/dev/null; then
    printf '%s\n' "ERRO: nao foi possivel recuperar o play.sh funcional do commit f6d7c6b." >&2
    exit 1
fi

# Remove somente o painel antigo do play.sh-base. O restante do orquestrador
# permanece byte-a-byte vindo do commit funcional.
_TMP="$_RUNTIME.tmp"
if ! awk '/^#  PAINEL$/{exit} {print}' "$_RUNTIME" > "$_TMP"; then
    rm -f "$_TMP"
    exit 1
fi
mv "$_TMP" "$_RUNTIME"

cat >> "$_RUNTIME" <<'EOF'
# ============================================================
#  PAINEL
#  Mantem o layout original e usa a camada LIVE da feature quando disponivel.
# ============================================================
. "$TWMDIR/panel.sh"
[ -f "$TWMDIR/panel_live.sh" ] && . "$TWMDIR/panel_live.sh"
PANEL_SUPERVISE=1
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s); painel oculto (sem terminal)"
painel_loop
EOF

chmod +x "$_RUNTIME" 2>/dev/null
exec sh "$_RUNTIME" "$@"
