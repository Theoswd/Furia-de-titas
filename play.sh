#!/bin/sh
# play.sh - Orquestrador multi-contas TWM
#
# A branch tinha recebido apenas o trecho final do painel, removendo a
# inicializacao do orquestrador (TWMDIR, contas, workers, etc.).
# Recupera exatamente a versao funcional do commit-base e troca somente o
# trecho final do painel pelo painel_live da feature.

TWMDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
export TWMDIR

_RUNTIME="$TWMDIR/.play.runtime.$$"
_cleanup() {
    rm -f "$_RUNTIME"
}
trap _cleanup EXIT INT TERM HUP

# A branch nasceu diretamente de f6d7c6b. Reutilizamos o play.sh funcional
# desse commit para nao duplicar/reinventar as 400+ linhas do orquestrador.
# O arquivo temporario fica dentro do repositorio para que o proprio script
# continue resolvendo TWMDIR para a raiz correta.
if ! git -C "$TWMDIR" show f6d7c6b:play.sh > "$_RUNTIME" 2>/dev/null; then
    printf '%s\n' "ERRO: nao foi possivel recuperar o play.sh funcional do commit f6d7c6b." >&2
    exit 1
fi

# O play.sh antigo termina com o painel. Removemos apenas as 9 linhas finais
# desse bloco e instalamos a versao do painel usada por esta feature.
_i=0
while [ "$_i" -lt 9 ]; do
    sed -i '$d' "$_RUNTIME" 2>/dev/null || {
        # fallback para ambientes sem sed -i
        _TMP="$_RUNTIME.tmp"
        sed '$d' "$_RUNTIME" > "$_TMP" && mv "$_TMP" "$_RUNTIME"
    }
    _i=$((_i + 1))
done
unset _i

cat >> "$_RUNTIME" <<'EOF'
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
EOF

chmod +x "$_RUNTIME" 2>/dev/null
sh "$_RUNTIME" "$@"
_status=$?
exit "$_status"
