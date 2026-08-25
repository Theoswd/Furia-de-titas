#!/bin/sh
# action_runner.sh - executor sequencial POSIX para atividades baseadas em links.
# Reabre/usa a resposta mais recente, nunca envia URL vazia e consulta o
# priority_guard entre acoes quando o scheduler novo estiver carregado.

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

    while [ "$(date +%s)" -lt "$_ar_end" ]; do
        _ar_link=`grep -o -E "$_ar_pattern" "$_ar_output" 2>/dev/null | sed -n '1p'`
        [ -n "$_ar_link" ] || break

        if command -v priority_guard >/dev/null 2>&1; then
            priority_guard || {
                printf '%s: interrompida por prioridade superior\n' "$_ar_label"
                unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count
                return 2
            }
        fi

        if ! fetch_page "$_ar_link" "$_ar_output"; then
            printf '%s: falha ao executar %s\n' "$_ar_label" "$_ar_link"
            unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count
            return 1
        fi

        _ar_count=$((_ar_count + 1))
        printf '%s: acao %s concluida\n' "$_ar_label" "$_ar_count"
    done

    ACTIVITY_RUN_COUNT=$_ar_count
    export ACTIVITY_RUN_COUNT
    unset _ar_page _ar_pattern _ar_timeout _ar_label _ar_output _ar_end _ar_link _ar_count
    return 0
}
