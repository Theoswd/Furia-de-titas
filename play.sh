#!/bin/sh
# play.sh - Orquestrador multi-contas TWM

# CORRECAO (seguranca): sem umask, ~/.twm e o accounts.conf nasciam 755/644.
umask 077

TOYBOX="$HOME/.multcf/toybox"
if [ ! -x "$TOYBOX" ]; then
    TOYBOX="sh"
fi
export TOYBOX

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
unset _dir
export TWMDIR

ACCOUNTS_FILE="$TWMDIR/accounts.conf"

termux-wake-lock 2>/dev/null
STATUS_DIR="$HOME/.twm/status"
RUN="${1:--boot}"

GREEN='\033[32m'
GOLD='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[01;36m'
YELLOW='\033[1;33m'
RESET='\033[00m'

mkdir -p "$STATUS_DIR"
chmod 700 "$HOME/.twm" 2>/dev/null
[ -f "$ACCOUNTS_FILE" ] && chmod 600 "$ACCOUNTS_FILE" 2>/dev/null

chmod +x "$TWMDIR/worker.sh" "$TWMDIR/twm.sh" 2>/dev/null

# setsid torna o worker lider de grupo de processos. Sem isso, matar o worker
# deixa o twm.sh filho ORFAO e vivo, e ao rodar ./play.sh de novo a conta
# passa a ter duas sessoes simultaneas disputando o mesmo cookie.
if command -v setsid > /dev/null 2>&1; then
    SETSID="setsid"
else
    SETSID=""
fi

server_url() {
    case "$1" in
        1)  echo "furiadetitas.net" ;;   2)  echo "titanen.mobi" ;;
        3)  echo "guerradetitanes.net" ;; 4)  echo "tiwar.fr" ;;
        5)  echo "in.tiwar.net" ;;        6)  echo "tiwar-id.net" ;;
        7)  echo "guerradititani.net" ;;  8)  echo "tiwar.pl" ;;
        9)  echo "tiwar.ro" ;;            10) echo "tiwar.ru" ;;
        11) echo "rs.tiwar.net" ;;        12) echo "cn.tiwar.net" ;;
        13) echo "tiwar.net" ;;
    esac
}

# O servidor IN (in.tiwar.net) recusa conexao na porta 443 e so atende em
# HTTP. Como o codigo montava "https://" fixo para todos, esse servidor
# nunca funcionou. ATENCAO: em HTTP a senha trafega em texto claro.
server_scheme() {
    case "$1" in
        5) echo "http" ;;
        *) echo "https" ;;
    esac
}

server_tag() {
    case "$1" in
        1) echo "BR" ;;  2) echo "DE" ;;  3) echo "ES" ;;
        4) echo "FR" ;;  5) echo "IN" ;;  6) echo "ID" ;;
        7) echo "IT" ;;  8) echo "PL" ;;  9) echo "RO" ;;
        10) echo "RU" ;; 11) echo "SR" ;; 12) echo "ZH" ;;
        13) echo "EN" ;;
    esac
}

# Remove CR (accounts.conf editado no Windows) e caracteres de controle.
clean_field() {
    printf '%s' "$1" | tr -d '\r' | tr -d '\000-\037'
}

# Mata o worker E seus filhos, mas so se o PID ainda for realmente um worker.
#
# CORRECAO: antes era "kill -0 PID && kill -9 PID". O kill -0 verifica
# EXISTENCIA, nao IDENTIDADE: com o PID reciclado pelo kernel, o kill -9
# acertava um processo inocente. Alem disso matava so o pai, deixando o
# twm.sh filho orfao e ativo.
kill_worker_tree() {
    kw_pid="$1"
    [ -n "$kw_pid" ] || return 1
    case "$kw_pid" in *[!0-9]*) return 1 ;; esac

    if [ -r "/proc/$kw_pid/cmdline" ]; then
        tr '\0' ' ' < "/proc/$kw_pid/cmdline" 2>/dev/null | grep -q 'worker\.sh' || return 1
    else
        kill -0 "$kw_pid" 2>/dev/null || return 1
    fi

    kill -TERM "-$kw_pid" 2>/dev/null || kill -TERM "$kw_pid" 2>/dev/null
    sleep 2
    if kill -0 "$kw_pid" 2>/dev/null; then
        kill -KILL "-$kw_pid" 2>/dev/null || kill -KILL "$kw_pid" 2>/dev/null
    fi
    return 0
}

# Sobe o worker de uma conta.  $1=srv  $2=usuario  $3=credencial (opcional)
launch_worker() {
    lw_srv="$1"
    lw_user="$2"
    lw_enc="$3"

    lw_tag=$(server_tag "$lw_srv")
    lw_host=$(server_url "$lw_srv")
    lw_scheme=$(server_scheme "$lw_srv")
    [ -n "$lw_tag" ] && [ -n "$lw_host" ] || return 1

    lw_id="${lw_tag}_${lw_user}"
    lw_dir="$HOME/.twm/${lw_id}"
    lw_status="$STATUS_DIR/${lw_id}.status"
    lw_pidf="$STATUS_DIR/${lw_id}.pid"
    lw_log="$lw_dir/twm.log"

    mkdir -p "$lw_dir"
    chmod 700 "$lw_dir" 2>/dev/null

    [ ! -f "$lw_dir/userAgent.txt" ] && [ -f "$TWMDIR/userAgent.txt" ] && \
        cp "$TWMDIR/userAgent.txt" "$lw_dir/userAgent.txt"

    # CORRECAO (seguranca): a credencial era passada como argv[3] do
    # worker.sh e ficava legivel em /proc/PID/cmdline durante toda a vida do
    # processo (o worker roda para sempre). Agora e gravada aqui, em arquivo
    # modo 600, e o worker recebe apenas o caminho do diretorio da conta.
    if [ -n "$lw_enc" ]; then
        printf '%s\n' "$lw_enc" > "$lw_dir/cript_file"
        chmod 600 "$lw_dir/cript_file"
    fi

    if [ ! -s "$lw_dir/cript_file" ]; then
        printf "   sem credencial para %s - pulando\n" "$lw_id"
        return 1
    fi

    if [ -f "$lw_pidf" ]; then
        kill_worker_tree "$(cat "$lw_pidf" 2>/dev/null)"
        rm -f "$lw_pidf"
    fi

    # Limpa o modo salvo para que a flag de linha de comando vença num
    # inicio limpo (o cave.sh regrava em runtime se trocar de modo).
    rm -f "$lw_dir/runmode_file"

    echo "starting" > "$lw_status"

    TOYBOX="$TOYBOX" _TOYBOX_RUNNING="1" \
    nohup $SETSID "$TOYBOX" "$TWMDIR/worker.sh" \
        "$lw_srv" "$lw_user" "$lw_tag" \
        "${lw_scheme}://${lw_host}" "$lw_dir" "$lw_status" "$RUN" \
        < /dev/null >> "$lw_log" 2>&1 &

    return 0
}

if [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ]; then
    printf "${RED}Nenhuma conta cadastrada.${RESET}\n"
    printf "Execute: ${GOLD}./setup.sh${RESET}\n"
    exit 1
fi

# CORRECAO: era "grep -c '|' ... || echo 0". Quando o grep nao acha nada ele
# imprime 0 E sai com status 1, entao o "|| echo 0" acrescentava um segundo 0
# e a variavel virava "0\n0". Alem disso contava linhas comentadas.
total=$(grep -c -E '^[0-9]+\|' "$ACCOUNTS_FILE" 2>/dev/null)
case "$total" in *[!0-9]*) total=0 ;; esac
[ -z "$total" ] && total=0

printf "${CYAN}TWM Multi-contas - %s conta(s) [%s]${RESET}\n\n" "$total" "$TOYBOX"

n=0

while IFS='|' read -r srv user encoded <&3; do
    srv=$(clean_field "$srv")
    user=$(clean_field "$user")
    encoded=$(clean_field "$encoded")

    case "$srv" in
        ''|\#*) continue ;;
        *[!0-9]*) continue ;;
    esac
    [ -z "$user" ] || [ -z "$encoded" ] && continue
    case "$user" in
        */*) printf "${RED}Nome invalido (contem barra): %s${RESET}\n" "$user"; continue ;;
    esac

    tag=$(server_tag "$srv")
    if [ -z "$tag" ]; then
        printf "${RED}Servidor desconhecido: %s - pulando${RESET}\n" "$srv"
        continue
    fi

    n=$((n + 1))
    acc_id="${tag}_${user}"
    log_file="$HOME/.twm/${acc_id}/twm.log"
    pid_file="$STATUS_DIR/${acc_id}.pid"

    printf "${GOLD}[%d/%d]${RESET} [%s] %s\n" "$n" "$total" "$tag" "$user"
    if [ "$(server_scheme "$srv")" = "http" ]; then
        printf "   ${YELLOW}AVISO: este servidor nao suporta HTTPS - senha em texto claro${RESET}\n"
    fi

    if ! launch_worker "$srv" "$user" "$encoded"; then
        continue
    fi

    pid=""
    _w=0
    while [ -z "$pid" ] && [ "$_w" -lt 10 ]; do
        sleep 1
        pid=$(cat "$pid_file" 2>/dev/null)
        _w=$((_w + 1))
    done
    printf "   PID: %s | Log: %s\n" "${pid:-FALHOU}" "$log_file"
    [ -z "$pid" ] && printf "   ${RED}AVISO: worker nao iniciou. Verifique %s${RESET}\n" "$log_file"

    # Espacamento entre contas. Sem isso todas autenticavam no mesmo segundo,
    # do mesmo IP: o rate-limit derrubava quase todas e o backoff exponencial
    # (ate 300s) mantinha as contas sincronizadas reincidindo em bloco.
    if [ "$n" -lt "$total" ]; then
        _jit=$(( (n * 7 + $$ % 13) % 16 + 5 ))
        printf "   aguardando %ss antes da proxima conta\n" "$_jit"
        sleep "$_jit"
    fi

done 3< "$ACCOUNTS_FILE"

if [ "$n" -eq 0 ]; then
    printf "${RED}Nenhuma conta valida encontrada em accounts.conf${RESET}\n"
    printf "Verifique o formato: srv|usuario|credencial_base64\n"
    exit 1
fi

printf "\n${GREEN}%s worker(s) iniciado(s).${RESET}\n\n" "$n"
printf "Log de conta:  ${CYAN}tail -f ~/.twm/BR_NomeConta/twm.log${RESET}\n"
printf "Parar tudo:    ${CYAN}./stop.sh${RESET}\n\n"
# Monitor — reabre accounts.conf a cada ciclo via fd3
# Painel so faz sentido com terminal. Sob systemd (ou qualquer saida
# redirecionada) ele seria reimpresso a cada 20s no journal; nesse caso
# o laco continua supervisionando e relancando workers, em silencio.
if [ -t 1 ]; then HAS_TTY=1; else HAS_TTY=0; fi
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s); painel oculto (sem terminal)"

W="======================================"

while true; do
    [ -t 1 ] && clear
    now=$(date +%H:%M:%S)

    [ "$HAS_TTY" = 1 ] && printf "╔%s╗\n" "$W"
    [ "$HAS_TTY" = 1 ] && printf "║  TWM Multi-contas        %s  ║\n" "$now"
    [ "$HAS_TTY" = 1 ] && printf "╠%s╣\n" "$W"

    while IFS='|' read -r srv user _enc <&3; do
        srv=$(clean_field "$srv")
        user=$(clean_field "$user")
        case "$srv" in ''|\#*|*[!0-9]*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        [ -z "$tag" ] && continue
        acc_id="${tag}_${user}"
        status_file="$STATUS_DIR/${acc_id}.status"
        pid_file="$STATUS_DIR/${acc_id}.pid"
        status=$(cat "$status_file" 2>/dev/null || echo "?")
        pid=$(cat "$pid_file" 2>/dev/null)

        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "dead" > "$status_file"
            # Worker morto (OOM killer do Android, por exemplo). Antes o
            # monitor apenas EXIBIA "ERRO" e a conta ficava parada para
            # sempre. Agora ele resobe o worker desta conta.
            printf "[monitor] relancando worker\n" >> "$HOME/.twm/${acc_id}/twm.log" 2>/dev/null
            launch_worker "$srv" "$user" "" > /dev/null 2>&1
            status="dead"
        fi

        case "$status" in
            running)     col="\033[32m" label="online"      ;;
            loading)     col="\033[33m" label="carregando"  ;;
            login_retry) col="\033[33m" label="login..."    ;;
            restarting)  col="\033[33m" label="reiniciando" ;;
            starting)    col="\033[33m" label="iniciando"   ;;
            dead)        col="\033[31m" label="ERRO"        ;;
            stopped)     col="\033[31m" label="parado"      ;;
            *)           col="\033[33m" label="$status"     ;;
        esac

        entry=$(printf "[%s] %-16s %-10s" "$tag" "$user" "$label")
        [ "$HAS_TTY" = 1 ] && printf "║  %b* %s\033[00m  ║\n" "$col" "$entry"

    done 3< "$ACCOUNTS_FILE"

    [ "$HAS_TTY" = 1 ] && printf "╚%s╝\n" "$W"

    _i=0
    while [ "$_i" -lt 20 ]; do
        sleep 1
        _i=$((_i + 1))
    done
done
