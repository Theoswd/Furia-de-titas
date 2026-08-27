#!/bin/sh
# saude.sh - Relatorio unico do estado de todas as contas
#
# Feito para quem NAO esta com o aparelho: uma execucao imprime, numa tela
# so, tudo que costuma ser perguntado num diagnostico remoto. Basta um print
# da saida.
#
# Somente leitura: nao toca em processo, nao faz login, nao usa a rede.
#
# Uso:  ./saude.sh

umask 077
TWMHOME="$HOME/.twm"
STATUS_DIR="$TWMHOME/status"

G='\033[1;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[1;36m'; D='\033[2m'; N='\033[0m'

[ -d "$TWMHOME" ] || { printf "${R}Bot nunca executado neste aparelho.${N}\n"; exit 1; }

AGORA=$(date +%s)

idade() {   # $1 = epoch -> "Nm" ou "-"
    case "$1" in ''|*[!0-9]*) printf '%s' "-"; return ;; esac
    printf '%sm' "$(( (AGORA - $1) / 60 ))"
}

printf "${C}=== SAUDE DAS CONTAS ===${N}  %s\n" "$(date '+%d/%m %H:%M')"

# --- ambiente
printf "\n${C}Aparelho${N}\n"
printf "  memoria livre: %s\n" "$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{printf "%d MB", $2/1024}')"
_pb=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
printf "  processos totais: %s\n" "$_pb"
_pw=0
for _p in /proc/[0-9]*; do
    [ -r "$_p/cmdline" ] || continue
    tr '\0' ' ' < "$_p/cmdline" 2>/dev/null | grep -qE 'worker\.sh|twm\.sh' && _pw=$((_pw + 1))
done
printf "  processos do bot: %s\n" "$_pw"
[ "$_pw" -gt 28 ] && printf "  ${Y}perto do limite de 32 do Android 12+${N}\n"

# --- contas
printf "\n${C}Contas${N}\n"
printf "  %-16s %-6s %-8s %-8s %-9s %s\n" "CONTA" "PROC" "SESSAO" "NUMEROS" "RELOGINS" "ULTIMA LINHA DO LOG"

_tot=0; _on=0; _sess_ok=0; _sess_ruim=0
for _d in "$TWMHOME"/BR_*/; do
    [ -d "$_d" ] || continue
    _acc=$(basename "${_d%/}")
    _nome=$(printf '%s' "$_acc" | sed 's/^BR_//')
    _tot=$((_tot + 1))

    # processo vivo?
    _pid=$(cat "$STATUS_DIR/${_acc}.pid" 2>/dev/null)
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then _proc="on"; _on=$((_on + 1))
    else _proc="OFF"; fi

    # sessao no jogo
    _ok=$(cat "${_d}last_ok" 2>/dev/null)
    _si=$(idade "$_ok")
    case "$_ok" in
        ''|*[!0-9]*) _sess="?" ; _sess_ruim=$((_sess_ruim + 1)) ;;
        *) if [ $(( (AGORA - _ok) / 60 )) -gt 4 ]; then _sess="CAIDA"; _sess_ruim=$((_sess_ruim + 1))
           else _sess="$_si"; _sess_ok=$((_sess_ok + 1)); fi ;;
    esac

    # idade dos numeros do painel
    _num="-"
    if [ -s "${_d}stats" ]; then
        _ts=$(awk -F'|' '{print $8}' "${_d}stats" 2>/dev/null)
        _num=$(idade "$_ts")
    fi

    # quantos relogins nas ultimas 200 linhas do log
    _rel=$(tail -n 200 "${_d}twm.log" 2>/dev/null | grep -c 'reconectando\|login falhou\|nao respondeu')

    _ult=$(tail -n 1 "${_d}twm.log" 2>/dev/null | cut -c1-32)

    printf "  %-16.16s %-6s %-8s %-8s %-9s %s\n" \
        "$_nome" "$_proc" "$_sess" "$_num" "$_rel" "$_ult"
done

printf "\n${C}Resumo${N}\n"
printf "  contas: %s   processo vivo: %s   sessao ok: %s   sessao ruim: %s\n" \
    "$_tot" "$_on" "$_sess_ok" "$_sess_ruim"

# --- leitura
printf "\n${C}Como ler${N}\n"
printf "  ${D}PROC${N}     worker rodando (nao significa online no jogo)\n"
printf "  ${D}SESSAO${N}   ha quanto tempo a sessao foi confirmada; CAIDA = passou de 4 min\n"
printf "  ${D}NUMEROS${N}  idade dos dados do painel (HP, energia, ouro)\n"
printf "  ${D}RELOGINS${N} reconexoes e recusas nas ultimas 200 linhas do log\n"

if [ "$_sess_ruim" -gt 0 ]; then
    printf "\n${Y}%s conta(s) com sessao ruim.${N}\n" "$_sess_ruim"
    printf "  ${D}Poucas e passageiras: normal, o bot reconecta sozinho.${N}\n"
    printf "  ${D}Muitas e persistentes, com RELOGINS alto: o servidor esta${N}\n"
    printf "  ${D}derrubando sessao por excesso de contas no mesmo IP.${N}\n"
fi
