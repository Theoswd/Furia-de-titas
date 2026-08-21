#!/bin/sh
# sigkill.sh - Descobre POR QUE o Android esta matando o bot
#
# O "[Process completed (signal 9)]" e SIGKILL: alguem de fora matou o
# processo. SIGKILL nao pode ser capturado nem registrado pelo proprio
# programa, entao a unica forma de saber a causa e observar de fora e
# gravar em disco — o log sobrevive mesmo que o Termux inteiro morra.
#
# Uso:
#   ./sigkill.sh            inicia o bot sob observacao
#   ./sigkill.sh relatorio  mostra o que ficou registrado da ultima vez
#
# Depois de reproduzir a morte, rode "./sigkill.sh relatorio" e mande a
# saida — ela diz se foi falta de memoria, limite de processos, ou outra
# coisa.

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

LOG="$HOME/.twm/sigkill.log"
mkdir -p "$HOME/.twm"

reg() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >> "$LOG"; }

# Memoria disponivel, em MB. O MemAvailable e o numero que o Android usa
# para decidir quem matar — o MemFree sozinho engana.
mem_mb() {
    _m=$(grep -E '^MemAvailable:' /proc/meminfo 2>/dev/null | tr -cd '0-9')
    [ -n "$_m" ] || _m=$(grep -E '^MemFree:' /proc/meminfo 2>/dev/null | tr -cd '0-9')
    case "$_m" in ''|*[!0-9]*) echo "?" ; return ;; esac
    echo $((_m / 1024))
}

# Processos do usuario. E este numero que o Android 12+ compara com o
# limite de 32 processos "fantasma".
n_proc() {
    _n=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)
    case "$_n" in ''|*[!0-9]*) echo "?" ;; *) echo "$_n" ;; esac
}

n_bot() {
    _c=0
    for _p in /proc/[0-9]*; do
        [ -r "$_p/cmdline" ] || continue
        case "$(tr '\0' ' ' < "$_p/cmdline" 2>/dev/null)" in
            *twm.sh*|*worker.sh*|*play.sh*|*curl*) _c=$((_c + 1)) ;;
        esac
    done
    echo "$_c"
}

ambiente() {
    reg "=== AMBIENTE ==="
    reg "  Android SDK : $(getprop ro.build.version.sdk 2>/dev/null || echo '?')"
    reg "  aparelho    : $(getprop ro.product.model 2>/dev/null || echo '?')"
    reg "  memoria tot : $(grep MemTotal /proc/meminfo 2>/dev/null | tr -cd '0-9' | awk '{print int($1/1024)" MB"}')"
    reg "  memoria disp: $(mem_mb) MB"
    reg "  processos   : $(n_proc)"
    reg "  setsid      : $(command -v setsid > /dev/null 2>&1 && echo sim || echo 'NAO (pkg install util-linux)')"
    reg "  termux-api  : $(command -v termux-wake-lock > /dev/null 2>&1 && echo sim || echo nao)"
    reg "  phantom     : $(settings get global settings_enable_monitor_phantom_procs 2>/dev/null || echo 'sem acesso')"
    reg "  max_phantom : $(settings get global max_phantom_processes 2>/dev/null || echo 'sem acesso')"
    reg "  disco livre : $(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
    reg ""
}

# O que o sistema registrou sobre o Termux. Sem READ_LOGS o Android so
# devolve as linhas do proprio app, entao pode vir vazio — nesse caso a
# ausencia nao prova nada, e os numeros de memoria acima e que valem.
sistema() {
    reg "=== REGISTRO DO SISTEMA (logcat) ==="
    if command -v logcat > /dev/null 2>&1; then
        logcat -d -t 300 2>/dev/null \
            | grep -iE 'termux|lowmemory|lmk|kill|phantom|anr|oom' \
            | tail -25 | sed 's/^/  /' >> "$LOG" 2>/dev/null \
            || reg "  (logcat sem permissao de leitura)"
    else
        reg "  (logcat indisponivel)"
    fi
    reg ""
}

if [ "$1" = "relatorio" ] || [ "$1" = "-r" ]; then
    [ -s "$LOG" ] || { printf "Nada registrado ainda. Rode ./sigkill.sh primeiro.\n"; exit 1; }
    cat "$LOG"
    exit 0
fi

: > "$LOG"
reg "=== INICIO $(date '+%d/%m %H:%M:%S') ==="
ambiente

printf "Observando. Deixe rodar ate o bot morrer.\n"
printf "Registro: %s\n\n" "$LOG"

# O play.sh fica em PRIMEIRO plano, para voce ver o painel normalmente.
# O observador roda ao lado e escreve em disco.
(
    _pico_proc=0
    _min_mem=999999
    while :; do
        _p=$(n_bot); _m=$(mem_mb); _t=$(n_proc)
        case "$_p" in ''|*[!0-9]*) _p=0 ;; esac
        [ "$_p" -gt "$_pico_proc" ] && _pico_proc="$_p"
        case "$_m" in ''|*[!0-9]*) ;; *) [ "$_m" -lt "$_min_mem" ] && _min_mem="$_m" ;; esac
        reg "proc_bot=$_p  proc_total=$_t  mem_disp=${_m}MB  (pico $_pico_proc)"
        echo "$_pico_proc $_min_mem" > "$HOME/.twm/.sigkill_pico"
        # 1s, nao 2: os processos de parsing (grep, sed) duram
        # milissegundos, e uma amostragem lenta simplesmente nao ve o pico
        # — que e justamente o numero que o Android compara com o limite.
        sleep 1
    done
) &
OBS=$!

# Encerra o observador junto, sem deixar processo solto.
trap 'kill "$OBS" 2>/dev/null' EXIT INT TERM

"$TWMDIR/play.sh" "$@"
_rc=$?

kill "$OBS" 2>/dev/null
trap - EXIT INT TERM

reg ""
reg "=== FIM: play.sh saiu com codigo $_rc ==="
[ -r "$HOME/.twm/.sigkill_pico" ] && {
    read -r _pk _mm < "$HOME/.twm/.sigkill_pico"
    reg "  pico de processos do bot : $_pk"
    reg "  memoria disponivel minima: ${_mm}MB"
}
# A lista nomeada revela worker orfao de execucao anterior: eles sobrevivem
# ao SIGKILL (nohup+setsid) e vao se acumulando a cada tentativa, cada um
# contando para o limite do Android.
reg "=== PROCESSOS DO BOT QUE FICARAM VIVOS ==="
_achou=0
for _p in /proc/[0-9]*; do
    [ -r "$_p/cmdline" ] || continue
    _c=$(tr '\0' ' ' < "$_p/cmdline" 2>/dev/null)
    case "$_c" in
        *twm.sh*|*worker.sh*|*play.sh*) reg "  ${_p#/proc/}  $_c"; _achou=1 ;;
    esac
done
[ "$_achou" = 0 ] && reg "  (nenhum — nada ficou para tras)"
reg ""

ambiente
sistema

printf "\n"
printf "O bot parou. Rode isto e mande a saida:\n"
printf "  ./sigkill.sh relatorio\n"
