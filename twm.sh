#!/bin/sh
# shellcheck disable=SC1091
# twm.sh - Worker de conta individual (nao interativo)
# Executado pelo worker.sh com o shell correto via $TOYBOX

TOYBOX="${TOYBOX:-sh}"

umask 077

if [ -z "$TWMDIR" ]; then
    _d=$(dirname "$0")
    TWMDIR=$(cd "$_d" && pwd)
    unset _d
    export TWMDIR
fi

if [ -z "$TWM_SRV" ] || [ -z "$TWM_URL" ] || [ -z "$TWM_ACC_DIR" ]; then
    printf "ERRO: twm.sh deve ser chamado pelo worker.sh\n"
    exit 1
fi

URL="$TWM_URL"
UR="$TWM_SRV"
TMP="$TWM_ACC_DIR"
TMP_COOKIE="$TMP/cookie.txt"
export URL UR TMP TMP_COOKIE

# Servidor unico (BR): fuso fixo.
export TZ="America/Bahia"

mkdir -p "$TMP"
chmod 700 "$TMP" 2>/dev/null

[ -n "$TWM_STATUS_FILE" ] && echo "loading" > "$TWM_STATUS_FILE"

. "$TWMDIR/info.sh"
. "$TWMDIR/session_check.sh"
colors

# Modo de execucao.
#
# CORRECAO (multi-contas): a versao anterior IGNORAVA o "$1" que o worker.sh
# passa e lia "$TWMDIR/runmode_file" — um arquivo unico, compartilhado por
# TODAS as contas. Resultado: "./play.sh -cv" e "-cl" nao tinham efeito, e
# uma conta trocando de modo trocava o modo de todas as outras.
# Agora: o runmode_file e por conta (escrito pelo run.sh/cave.sh em runtime)
# e tem prioridade; o play.sh o apaga a cada lancamento, entao a flag de
# linha de comando vence num inicio limpo.
if [ -s "$TMP/runmode_file" ]; then
    RUN=$(cat "$TMP/runmode_file" 2>/dev/null)
elif [ -n "$1" ]; then
    RUN="$1"
fi
[ -z "$RUN" ] && RUN='-boot'
export RUN

if [ -d /data/data/com.termux/files/usr/share/doc ]; then
    termux-wake-lock 2>/dev/null
fi

cd "$TWMDIR" || exit 1
for _lib in \
    language.sh requeriments.sh loginlogoff.sh \
    flagfight.sh clanid.sh crono.sh arena.sh coliseum.sh \
    campaign.sh run.sh altars.sh clandmg.sh clanfight.sh \
    clancoliseum.sh king.sh undying.sh trade.sh career.sh \
    cave.sh allies.sh svproxy.sh check.sh league.sh \
    specialevent.sh function.sh update_check.sh
do
    [ -f "$TWMDIR/$_lib" ] && . "$TWMDIR/$_lib"
done
unset _lib

type translate_and_cache > /dev/null 2>&1 || translate_and_cache() { echo "$2"; }

# CORRECAO: a ordem era language_setup depois load_config. Como o
# language_setup criava o config.cfg contendo so LANGUAGE=, o load_config
# encontrava o arquivo "ja existente" e nunca gravava os defaults. Agora o
# load_config vem primeiro e garante todas as chaves.
load_config
language_setup

if [ ! -f "$TMP/userAgent.txt" ] && [ -f "$TWMDIR/userAgent.txt" ]; then
    cp "$TWMDIR/userAgent.txt" "$TMP/userAgent.txt"
fi
random_ua 2>/dev/null
[ -z "$vUserAgent" ] && vUserAgent="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
export vUserAgent

[ ! -f "$TMP/allies.txt" ]  && : > "$TMP/allies.txt"
[ ! -f "$TMP/callies.txt" ] && : > "$TMP/callies.txt"

printf "[%s] %s — iniciando (modo %s)\n" "$TWM_TAG" "$TWM_USER" "$RUN"

# Login com retry — delay crescente com jitter, nunca mata o worker
do_login() {
    cript_file="$TMP/cript_file"
    if [ ! -s "$cript_file" ]; then
        printf "[%s] %s — ERRO: sem credenciais\n" "$TWM_TAG" "$TWM_USER"
        return 1
    fi

    creds=$(base64 -d "$cript_file" 2>/dev/null)
    if [ -z "$creds" ]; then
        printf "[%s] %s — ERRO: cript_file ilegivel\n" "$TWM_TAG" "$TWM_USER"
        return 1
    fi
    luser=$(echo "$creds" | sed 's/login=//;s/&pass=.*//')
    lpass=$(echo "$creds" | sed 's/.*&pass=//')
    unset creds

    # CORRECAO: a versao anterior enviava o MESMO POST de login duas vezes
    # (bloco copiado), dobrando o trafego de autenticacao de todas as contas
    # e ajudando a estourar o rate-limit do servidor. O primeiro acesso agora
    # e um GET, que apenas estabelece o cookie de sessao; a credencial e
    # enviada uma unica vez.
    run_curl "${URL}/" > /dev/null 2>&1

    run_curl --data-urlencode "login=${luser}" \
             --data-urlencode "pass=${lpass}" \
             "${URL}/?sign_in=1" > /dev/null
    unset luser lpass

    PAGE=$(run_curl "${URL}/user")
    if is_logged_in "$PAGE"; then
        ACC=$(extract_username "$PAGE")
        [ -z "$ACC" ] && ACC="$TWM_USER"
        export ACC
        # HP maximo muda pouco: busca uma vez por login, para o percentual.
        fetch_max_hp 2>/dev/null
        parse_status "$PAGE"
        # Grava a linha de status ja no login. Antes o msg_file so era
        # escrito dentro de start(), que roda apenas em minutos
        # especificos — entao o func_cat nao tinha o que exibir por
        # muito tempo, ou exibia um arquivo antigo.
        messages_info
        printf "[%s] %s — login OK\n" "$TWM_TAG" "$ACC"
        unset PAGE
        return 0
    fi
    unset PAGE
    return 1
}

login_delay=30
login_try=0
while true; do
    if do_login; then
        break
    fi
    login_try=$((login_try + 1))

    # Jitter: sem ele todas as contas que falham reincidem EM BLOCO no mesmo
    # instante (mesmo IP), mantendo o rate-limit do servidor permanentemente
    # ativo. Backoff sem aleatoriedade nao dispersa carga, so a agenda.
    _half=$(( login_delay / 2 ))
    _wait=$(( _half + ( ($$ + login_try) % (_half + 1) ) ))

    printf "[%s] %s — login falhou (tentativa %s), nova tentativa em %ss\n" \
        "$TWM_TAG" "$TWM_USER" "$login_try" "$_wait"
    [ -n "$TWM_STATUS_FILE" ] && echo "login_retry" > "$TWM_STATUS_FILE"
    sleep "$_wait"

    [ "$login_delay" -lt 300 ] && login_delay=$((login_delay * 2))
    [ "$login_delay" -gt 300 ] && login_delay=300
    rm -f "$TMP_COOKIE"
done

clan_id 2>/dev/null
func_proxy

twm_start() {
    case "$RUN" in
        *-cv*) cave_start ;;
        *-cl*) twm_play ;;
        *)     twm_play ;;
    esac
}

# Limpa o estado de combate entre ciclos.
# CORRECAO: a lista nao incluia CLD, FULL, RHP, HLHP, NOWHP, NOWMP, HPPER,
# MPPER nem ACCESS, entao valores velhos vazavam para o ciclo seguinte e
# contaminavam decisoes de cura/ataque.
func_unset() {
    unset HP1 HP2 YOU USER CLAN ENTER ATK ATKRND DODGE HEAL GRASS STONE \
          BEXIT OUTGATE LEAVEFIGHT WDRED CAVE BREAK NEWCAVE \
          FULL RHP HLHP ACCESS SHIELD UNRIP KINGATK
}

[ -n "$TWM_STATUS_FILE" ] && echo "running" > "$TWM_STATUS_FILE"
printf "[%s] %s — loop principal iniciado\n" "$TWM_TAG" "$ACC"

while true; do
    twm_start
done
