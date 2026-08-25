#!/bin/sh
# action_runner.sh - executor sequencial POSIX para atividades baseadas em links.
# Nunca envia URL vazia, respeita prioridade e nao chama resposta HTTP de
# "conclusao" sem prova semantica.

activity_run_links() {
    _ar_page="$1"
    _ar_pattern="$2"
    _ar_timeout="${3:-90}"
    _ar_label="${4:-atividade}"
    _ar_output="${5:-$TMP/SRC}"

    case "$_ar_timeout" in ''|*[!0-9]*) _ar_timeout=90 ;; esac

    fetch_page "$_ar_page" "$_ar_output" || return 1
    _ar_end=$(( $(date +%s) + _ar_timeout ))
    _ar_count=0
    _ar_last=""
    _ar_same=0

    while [ "$(date +%s)" -lt "$_ar_end" ]; do
        _ar_link=`grep -o -E "$_ar_pattern" "$_ar_output" 2>/dev/null | sed -n '1p'`
        [ -n "$_ar_link" ] || break

        # Evita loop fantasma quando o servidor devolve exatamente a mesma
        # acao repetidamente sem progresso.
        if [ "$_ar_link" = "$_ar_last" ]; then
            _ar_same=$((_ar_same + 1))
        else
            _ar_same=0
        fi
        [ "$_ar_same" -lt 3 ] || {
            printf '%s: mesma acao repetida sem progresso; abortando\n' "$_ar_label"
            ACTIVITY_RUN_COUNT=$_ar_count
            export ACTIVITY_RUN_COUNT
            unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count _ar_last _ar_same
            return 1
        }
        _ar_last="$_ar_link"

        if command -v priority_guard >/dev/null 2>&1; then
            priority_guard || {
                printf '%s: interrompida por prioridade superior\n' "$_ar_label"
                ACTIVITY_RUN_COUNT=$_ar_count
                export ACTIVITY_RUN_COUNT
                unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count _ar_last _ar_same
                return 2
            }
        fi

        if ! fetch_page "$_ar_link" "$_ar_output"; then
            printf '%s: falha ao enviar %s\n' "$_ar_label" "$_ar_link"
            ACTIVITY_RUN_COUNT=$_ar_count
            export ACTIVITY_RUN_COUNT
            unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count _ar_last _ar_same
            return 1
        fi

        if command -v is_logged_in >/dev/null 2>&1; then
            _ar_page_text=`cat "$_ar_output" 2>/dev/null`
            if ! is_logged_in "$_ar_page_text"; then
                printf '%s: sessao perdida apos acao\n' "$_ar_label"
                ACTIVITY_RUN_COUNT=$_ar_count
                export ACTIVITY_RUN_COUNT
                unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count _ar_last _ar_same _ar_page_text
                return 1
            fi
            unset _ar_page_text
        fi

        _ar_count=$((_ar_count + 1))
        printf '%s: acao %s enviada\n' "$_ar_label" "$_ar_count"
    done

    ACTIVITY_RUN_COUNT=$_ar_count
    export ACTIVITY_RUN_COUNT
    unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count _ar_last _ar_same
    return 0
}
