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

# PID do proprio orquestrador. Sem isto o stop.sh nao conseguia
# encerrar o monitor: ele roda como "./play.sh" (caminho relativo) e
# um pgrep por caminho absoluto nao casa. Cada ./play.sh deixava mais
# um monitor vivo, todos supervisionando as mesmas contas.
echo "$$" > "$STATUS_DIR/orchestrator.pid"
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

# ============================================================
#  SOMENTE SERVIDOR BR (furiadetitas.net)
#  O suporte aos outros 12 servidores foi removido a pedido.
#  O campo de servidor continua no accounts.conf (sempre "1")
#  para nao quebrar cadastros existentes.
# ============================================================
server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

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
    # 5s bastam: o worker grava o PID como primeira acao. Com 20 contas,
    # o limite antigo de 10s somava ate 200s de espera no pior caso.
    while [ -z "$pid" ] && [ "$_w" -lt 5 ]; do
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
        # Escalonamento adaptativo. O valor fixo de 5-20s por conta
        # levaria ate 6,7 minutos so para subir 20 contas. Agora a
        # janela total fica em torno de 3 minutos, qualquer que seja o
        # numero de contas, com um piso de 3s para nao autenticar todas
        # no mesmo instante (o servidor limita login por IP).
        _base=$(( 180 / total ))
        [ "$_base" -lt 3 ] && _base=3
        [ "$_base" -gt 15 ] && _base=15
        _jit=$(( _base + (n + $$) % 4 ))
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
# ============================================================
#  PAINEL
#  So faz sentido com terminal. Sob systemd (ou qualquer saida
#  redirecionada) seria reimpresso a cada 20s no journal; nesse
#  caso o laco segue supervisionando e relancando, em silencio.
# ============================================================
if [ -t 1 ]; then HAS_TTY=1; else HAS_TTY=0; fi
[ "$HAS_TTY" = 0 ] && echo "[monitor] supervisionando $n conta(s); painel oculto (sem terminal)"

LINHA="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Emoji conforme o estado do worker
estado_emoji() {
    case "$1" in
        running)                          echo "🟢" ;;
        starting|loading|login_retry|restarting) echo "🟡" ;;
        dead)                             echo "🔴" ;;
        stopped)                          echo "⚫" ;;
        *)                                echo "⚪" ;;
    esac
}

# Descobre o que a conta esta fazendo agora, a partir do log
atividade_de() {
    _lg="$1"
    [ -f "$_lg" ] || { echo "—"; return; }
    _l=`tail -n 25 "$_lg" 2>/dev/null | grep -iE "Arena|Career|Carreira|Cave|Caverna|Campaign|Campanha|Coliseu|Coliseum|Clan|King|Rei|Trade|Missions|Quest|Relic|Altars|League|Liga|Event|aguardando" | tail -n 1`
    case "$_l" in
        *Arena*|*arena*)             echo "⚔️  Arena" ;;
        *Career*|*Carreira*)         echo "🎖️  Carreira" ;;
        *Cave*|*Caverna*|*caverna*)  echo "⛏️  Caverna" ;;
        *Campaign*|*Campanha*)       echo "🗺️  Campanha" ;;
        *Colise*|*colise*)           echo "🏛️  Coliseu" ;;
        *Clan*|*clan*)               echo "🛡️  Clã" ;;
        *King*|*Rei*)                echo "👑  Rei" ;;
        *Trade*|*Troca*)             echo "💱  Troca" ;;
        *Quest*|*Mission*|*Missao*)  echo "📜  Missões" ;;
        *Relic*|*Reliquia*)          echo "💎  Relíquias" ;;
        *Altars*|*Altares*)          echo "🔥  Altares" ;;
        *League*|*Liga*)             echo "🏆  Liga" ;;
        *Event*|*Evento*)            echo "🎉  Evento" ;;
        *aguardando*)                echo "💤  Aguardando" ;;
        *)                           echo "—" ;;
    esac
    unset _lg _l
}

while true; do
    [ "$HAS_TTY" = 1 ] && clear
    agora=$(date +%H:%M:%S)

    tot_ouro=0; tot_prata=0; n_on=0; n_off=0; idx=0
    LISTA=""; ATIV=""

    while IFS='|' read -r srv user _enc <&3; do
        srv=$(clean_field "$srv")
        user=$(clean_field "$user")
        case "$srv" in ''|\#*|*[!0-9]*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        [ -z "$tag" ] && continue

        acc_id="${tag}_${user}"
        acc_dir="$HOME/.twm/${acc_id}"
        status_file="$STATUS_DIR/${acc_id}.status"
        pid_file="$STATUS_DIR/${acc_id}.pid"
        status=$(cat "$status_file" 2>/dev/null || echo "?")
        pid=$(cat "$pid_file" 2>/dev/null)

        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "dead" > "$status_file"
            status="dead"
            printf "[monitor] relancando worker\n" >> "$acc_dir/twm.log" 2>/dev/null
            launch_worker "$srv" "$user" "" > /dev/null 2>&1
        fi

        [ "$status" = "running" ] && n_on=$((n_on + 1)) || n_off=$((n_off + 1))
        idx=$((idx + 1))

        # Dados gravados pelo worker (sem requisicao extra aqui)
        nome="$user"; hp="-"; mp="-"; ene="-"; lvl="-"; ouro="-"; prata="-"
        if [ -s "$acc_dir/stats" ]; then
            IFS='|' read -r nome hp mp ene lvl ouro prata _ts < "$acc_dir/stats"
            [ -z "$nome" ] && nome="$user"
        fi
        case "$ouro"  in ''|*[!0-9]*) ;; *) tot_ouro=$((tot_ouro + ouro)) ;; esac
        case "$prata" in ''|*[!0-9]*) ;; *) tot_prata=$((tot_prata + prata)) ;; esac

        em=$(estado_emoji "$status")
        LISTA="${LISTA}$(printf ' %2s %s %-18.18s ❤️ %-7s ⚡ %-6s ⭐ %-4s 🪙 %-8s 🥈 %s' \
              "$idx" "$em" "$nome" "$hp" "$ene" "$lvl" "$ouro" "$prata")
"
        ATIV="${ATIV}$(printf '    %-18.18s ▸ %s' "$nome" "$(atividade_de "$acc_dir/twm.log")")
"
    done 3< "$ACCOUNTS_FILE"

    if [ "$HAS_TTY" = 1 ]; then
        printf '%s\n' "$LINHA"
        printf '  🎮 TWM Multi-contas · BR%*s%s\n' 28 '' "$agora"
        printf '%s\n' "$LINHA"
        printf '%s' "$LISTA"
        printf '%s\n' "$LINHA"
        printf '  📋 ATIVIDADE EM CONJUNTO\n'
        printf '%s' "$ATIV"
        printf '%s\n' "$LINHA"
        printf '  🟢 %s online   🔴 %s parada(s)      💰 Ouro %s   🥈 Prata %s\n' \
               "$n_on" "$n_off" "$tot_ouro" "$tot_prata"
        printf '%s\n' "$LINHA"
    fi

    _i=0
    while [ "$_i" -lt 20 ]; do
        sleep 1
        _i=$((_i + 1))
    done
done
