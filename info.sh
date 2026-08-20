#!/bin/sh

# CORRECAO: versionNum era definido apenas DENTRO de script_slogan(),
# funcao que nunca e chamada no fluxo do worker. Resultado: o messages_info
# imprimia "TWM - Titans War Macro v | ..." com a versao vazia.
versionNum="3.9.28"
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
    :  # valor definido no topo do arquivo
    printf "TWM - Titans War Macro v%s\n" "$versionNum"
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

# Extrai os dados da conta de uma pagina /user ja baixada e grava em
# $TMP/stats, que o painel do play.sh le. Nenhuma requisicao extra: o
# login_logoff() ja baixa essa pagina a cada ciclo.
#
# Campos nao encontrados viram "-" em vez de ficarem vazios, para o painel
# nao mentir sobre um valor que nao conseguiu ler.
#
# Padroes confirmados contra o HTML real do jogo:
#   <title>Grimlock</title>
#   health.png' alt='hp'/> <span class='white'>65312</span>
#   mana.png' alt='mp'/> 470</span>
#   icon/level.png' alt=''/> 40 nivel
#   mana.png' alt=''/> Energia: 2125
# Converte "408,1M" / "12K" / "396" em numero inteiro, para somar no painel.
# O jogo abrevia valores grandes; sem isso, "408,1M" virava 4081.
_para_num() {
    _v=`printf '%s' "$1" | tr -d ' '`
    case "$_v" in
        *K|*k) _m=1000 ;;
        *M|*m) _m=1000000 ;;
        *B|*b) _m=1000000000 ;;
        *)     _m=1 ;;
    esac
    _d=`printf '%s' "$_v" | tr ',' '.' | tr -cd '0-9.'`
    [ -z "$_d" ] && { echo 0; return; }
    awk -v d="$_d" -v m="$_m" 'BEGIN{ printf "%.0f", d*m }'
}

# Extrai os dados da conta de uma pagina /user ja baixada e grava em
# $TMP/stats, lido pelo painel do play.sh. Sem requisicao extra: o
# login_logoff() ja baixa essa pagina a cada ciclo.
#
# Padroes confirmados contra o HTML real:
#   <title>Grimlock</title>
#   health.png' alt='hp'/> <span class='white'>65312</span>
#   mana.png' alt='mp'/> 346
#   icon/level.png' alt='lvl'/> 90
#   icon/gold.png' alt='g'/> 396
#   icon/silver.png' alt='s'/> 408,1M
# Energia so aparece em /train: mana.png' alt=''/> Energia: 2125
parse_status() {
    _pg="$1"
    [ -n "$_pg" ] || return 1

    ACC_HP=`printf '%s' "$_pg" | grep -o -E "health\.png' alt='hp'/> <span[^>]*>[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_MP=`printf '%s' "$_pg" | grep -o -E "mana\.png' alt='mp'/>[^0-9<]{0,4}[0-9]{1,9}" | grep -o -E '[0-9]{1,9}$' | head -n1`
    ACC_LVL=`printf '%s' "$_pg" | grep -o -E "level\.png' alt='[^']*'/> ?[0-9]{1,4}" | grep -o -E '[0-9]{1,4}$' | head -n1`

    # Ouro e prata: guarda o texto como o jogo mostra (pode vir "408,1M").
    ACC_GOLD=`printf '%s' "$_pg" | grep -o -E "gold\.png' alt='[^']*'/> ?[0-9][0-9.,]{0,12}[KMBkmb]?" | sed -E "s@.*/> ?@@" | head -n1`
    ACC_SILVER=`printf '%s' "$_pg" | grep -o -E "silver\.png' alt='[^']*'/> ?[0-9][0-9.,]{0,12}[KMBkmb]?" | sed -E "s@.*/> ?@@" | head -n1`

    NOWHP="$ACC_HP"; NOWMP="$ACC_MP"

    if [ -n "$ACC_HP" ] && [ -n "$FIXHP" ] && [ "$FIXHP" -gt 0 ] 2>/dev/null; then
        HPPER=`awk -v a="$ACC_HP" -v b="$FIXHP" 'BEGIN{printf "%.0f", a/b*100}'`
    else
        HPPER=""
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "${ACC:-$TWM_USER}" "${ACC_HP:--}" "${ACC_MP:--}" "${ACC_ENE:--}" \
        "${ACC_LVL:--}" "${ACC_GOLD:--}" "${ACC_SILVER:--}" "$(date +%s)" \
        > "$TMP/stats" 2>/dev/null

    unset _pg
}

# Dados que so existem na pagina /train: HP maximo e energia.
# Uma requisicao por ciclo de start(), nao por minuto.
fetch_train_stats() {
    _t=`run_curl "${URL}/train" 2>/dev/null`
    [ -n "$_t" ] || return 1
    FIXHP=`printf '%s' "$_t" | grep -o -E '\([0-9]{1,9}\)' | head -n1 | tr -d '()'`
    ACC_ENE=`printf '%s' "$_t" | grep -o -E "Energia:? ?[0-9][0-9.,]{0,12}[KMBkmb]?" | sed -E 's@.*:? ?@@' | head -n1`
    [ -z "$ACC_ENE" ] && ACC_ENE=`printf '%s' "$_t" | grep -o -E "Energia:? ?[0-9.,]{1,15}" | grep -o -E '[0-9.,]{1,15}$' | head -n1`
    unset _t
}

# Compatibilidade: nome antigo usado pelo twm.sh
fetch_max_hp() { fetch_train_stats; }

# Linha de status no log da conta. Imprime so o que existe.
messages_info() {
    _a="${ACC:-$TWM_USER}"
    printf "TWM v%s | %s\n" "${versionNum:-?}" "$_a" > "$TMP/msg_file"
    if [ -n "$HPPER" ]; then
        printf "HP: %s (%s%%) | MP: %s | Energia: %s | Nivel: %s\n" \
            "${ACC_HP:--}" "$HPPER" "${ACC_MP:--}" "${ACC_ENE:--}" "${ACC_LVL:--}" >> "$TMP/msg_file"
    else
        printf "HP: %s | MP: %s | Energia: %s | Nivel: %s\n" \
            "${ACC_HP:--}" "${ACC_MP:--}" "${ACC_ENE:--}" "${ACC_LVL:--}" >> "$TMP/msg_file"
    fi
    unset _a
}

player_stats() {
    fetch_page "/train"
    STRENGTH=`grep -o -E ': [0-9]+' "$TMP/SRC" | sed -n '1s/: //p'`
    PLAYER_STRENGTH=`echo "$STRENGTH" | tr -cd '[:digit:]'`
    echo "$PLAYER_STRENGTH"
}
