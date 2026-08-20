#!/bin/sh
# shellcheck disable=SC2034
colors() {
    BLACK_BLACK='\033[00;30m'
    BLACK_CYAN='\033[01;36m\033[01;07m'
    BLACK_GREEN='\033[00;32m\033[01;07m'
    BLACK_GRAY='\033[01;30m\033[01;07m'
    BLACK_PINK='\033[01;35m\033[01;07m'
    BLACK_RED='\033[01;31m\033[01;07m'
    BLACK_YELLOW='\033[00;33m\033[01;07m'
    CYAN_BLACK='\033[04;36m\033[02;04m'
    CYAN_CYAN='\033[01;36m\033[08;07m'
    BLUE_BLACK='\033[0;34m'
    COLOR_RESET='\033[00m'
    GOLD_BLACK='\033[0;33m'
    GREEN_BLACK='\033[32m'
    GREENb_BLACK='\033[1;32m'
    RED_BLACK='\033[0;31m'
    PURPLEi_BLACK='\033[03;34m\033[02;03m'
    PURPLEis_BLACK='\033[03;34m\033[02;04m'
    WHITE_BLACK='\033[37m'
    WHITEb_BLACK='\033[01;38m\033[05;01m'
}

script_slogan() {
    versionNum="3.9.28"
    printf "TWM - Titans War Macro v%s\n" "$versionNum"
}

# Le o idioma do config da conta. NAO cria o arquivo.
#
# CORRECAO: antes esta funcao era chamada no momento do "source" deste
# arquivo (linha 39 da versao original). Como o twm.sh define $TMP antes
# de dar source, ela criava $TMP/config.cfg contendo APENAS "LANGUAGE=en".
# Em seguida load_config() encontrava o arquivo ja existente e nunca
# gravava os defaults -> todas as FUNC_* ficavam vazias em todas as contas.
# Agora quem garante as chaves e o load_config(), e a chamada automatica
# foi removida.
language_setup() {
    CONFIG_FILE="${TMP:-.}/config.cfg"
    LANGUAGE=`grep -E "^LANGUAGE=" "$CONFIG_FILE" 2>/dev/null | cut -d '=' -f2`
    [ -z "$LANGUAGE" ] && LANGUAGE="en"
    export LANGUAGE
}

printf_t() {
    local_text="$1"
    local_color_start="$2"
    local_color_end="$3"
    local_emoji_position="$4"
    local_emoji="$5"
    local_translated_text=`translate_and_cache "$LANGUAGE" "$local_text"`
    if [ "$local_emoji_position" = "before" ]; then
        printf "${local_color_start}%s %s${local_color_end}\n" "$local_emoji" "$local_translated_text"
    else
        printf "${local_color_start}%s %s${local_color_end}" "$local_translated_text" "$local_emoji"
    fi
}

echo_t() {
    local_text="$1"
    local_color_start="$2"
    local_color_end="$3"
    local_emoji_position="$4"
    local_emoji="$5"
    local_translated_text=`translate_and_cache "$LANGUAGE" "$local_text"`
    if [ "$local_emoji_position" = "before" ]; then
        printf "${local_color_start}%s %s${local_color_end}\n" "$local_emoji" "$local_translated_text"
    else
        printf "${local_color_start}%s %s${local_color_end}\n" "$local_translated_text" "$local_emoji"
    fi
}

# Aguarda o ultimo job em background terminar, ate N segundos.
#
# CORRECAO: a versao original rodava dentro de ( ... ) e extraia o PID com
#   TEFPID=`echo "$!" | grep -o -E '([0-9]{2,6})'`
# A regex trunca PIDs com 7+ digitos (pid_max pode chegar a 4194304), o que
# fazia o kill acertar um processo QUALQUER do usuario. Agora usa $! direto.
# O "sleep antes do teste" foi mantido de proposito: ele impoe ~1s de
# espacamento entre requisicoes, que e um limitador de taxa natural.
time_exit() {
    TEFPID=$!
    _te_max="$1"
    [ -z "$TEFPID" ] && return 0
    case "$_te_max" in ''|*[!0-9]*) _te_max=17 ;; esac

    _te_n=0
    while [ "$_te_n" -lt "$_te_max" ]; do
        sleep 1
        _te_n=$((_te_n + 1))
        if ! kill -0 "$TEFPID" 2>/dev/null; then
            wait "$TEFPID" 2>/dev/null
            unset _te_n _te_max
            return 0
        fi
    done

    kill -15 "$TEFPID" 2>/dev/null
    sleep 1
    kill -0 "$TEFPID" 2>/dev/null && kill -9 "$TEFPID" 2>/dev/null
    wait "$TEFPID" 2>/dev/null
    printf "timeout %ss: requisicao abortada\n" "$_te_max" >> "${TMP:-.}/ERROR_DEBUG"
    unset _te_n _te_max
    return 1
}

# Funcao central de requisicao via curl.
#
# CORRECOES:
#  --proto/--proto-redir : impede que um redirect leve a requisicao (e o
#                          corpo do POST de login) para fora de HTTPS.
#  --max-redirs          : limita cadeia de redirecionamento.
#  --connect-timeout /
#  --max-time            : sem isso, um socket pendurado travava o worker
#                          para sempre (as chamadas de login sao sincronas).
#  -sS em vez de -s      : mantem silencio de progresso MAS mostra erros,
#                          que antes eram engolidos ("parou e nao sei por que").
run_curl() {
    case "$URL" in
        http://*) _rc_p="--proto =http,https --proto-redir =http,https" ;;
        *)        _rc_p="--proto =https --proto-redir =https" ;;
    esac

    # shellcheck disable=SC2086
    if [ -n "$TMP_COOKIE" ]; then
        curl -sS -L --compressed --max-redirs 5 \
             --connect-timeout 15 --max-time 45 \
             $_rc_p -A "$vUserAgent" \
             -c "$TMP_COOKIE" -b "$TMP_COOKIE" "$@"
    else
        curl -sS -L --compressed --max-redirs 5 \
             --connect-timeout 15 --max-time 45 \
             $_rc_p -A "$vUserAgent" "$@"
    fi
}

# Acessa qualquer pagina pelo caminho relativo
fetch_page() {
    relative_url="$1"
    output_file="${2:-$TMP/SRC}"

    (
        run_curl "${URL}${relative_url}" > "$output_file"
    ) </dev/null > /dev/null 2>&1 &

    time_exit 17
}

hpmp() {
    if echo "$@" | grep -q '\-fix'; then
        (
            run_curl "$URL/train" > "$TMP/TRAIN"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 20
        FIXHP=`grep -o -E '\(([0-9]+)\)' "$TMP/TRAIN" | sed 's/[()]//g'`
        FIXMP=`grep -o -E ': [0-9]+' "$TMP/TRAIN" | sed -n '5s/: //p'`
    fi

    NOWHP=`grep -o -E "<img src='/images/icon/health.png' alt='hp'/> <span class='(dred|white)'>[ ]?[0-9]{1,7}[ ]?</span> | <img src='/images/icon/mana.png' alt='mp'/>" "$TMP/SRC" | tr -c -d '[:digit:]'`
    NOWMP=`grep -o -E "</span> | <img src='/images/icon/mana.png' alt='mp'/>[ ]?[0-9]{1,7}[ ]?</span><div class='clr'></div></div>" "$TMP/SRC" | tr -c -d '[:digit:]'`

    # CORRECAO: se a requisicao foi cortada pelo time_exit, FIXHP/FIXMP ficam
    # vazios e o awk fazia divisao por zero -> "nan"/"inf" nas comparacoes.
    if [ -n "$NOWHP" ] && [ -n "$FIXHP" ] && [ "$FIXHP" -gt 0 ] 2>/dev/null; then
        HPPER=`awk -v nowhp="$NOWHP" -v fixhp="$FIXHP" 'BEGIN { printf "%.2f", nowhp / fixhp * 100 }'`
    else
        HPPER="0.00"
    fi

    if [ -n "$NOWMP" ] && [ -n "$FIXMP" ] && [ "$FIXMP" -gt 0 ] 2>/dev/null; then
        MPPER=`awk -v nowmp="$NOWMP" -v fixmp="$FIXMP" 'BEGIN { printf "%.2f", nowmp / fixmp * 100 }'`
    else
        MPPER="0.00"
    fi
}

messages_info() {
    printf "TWM - Titans War Macro v%s | %s\n" "$versionNum" "$ACC" > "$TMP/msg_file"
    printf "HP: %s (%s%%) | MP: %s (%s%%)\n" "$NOWHP" "$HPPER" "$NOWMP" "$MPPER" >> "$TMP/msg_file"
}

player_stats() {
    fetch_page "/train"
    STRENGTH=`grep -o -E ': [0-9]+' "$TMP/SRC" | sed -n '1s/: //p'`
    PLAYER_STRENGTH=`echo "$STRENGTH" | tr -cd '[:digit:]'`
    echo "$PLAYER_STRENGTH"
}
