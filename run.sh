twm_play_legacy() {
    printf "ERRO: fluxo legado desativado por seguranca. Atualize a branch de teste.\n"
    return 1
}

restart_script() {
    printf "[%s] %s — reiniciando esta conta\n" "$TWM_TAG" "${ACC:-$TWM_USER}"
    exit 0
}

# run.sh e carregado antes dos demais modulos. O scheduler V2 so e sourced
# quando twm_play e chamado, depois que todos os modulos antigos ja foram
# definidos. Se priority.sh ou qualquer dependencia V2 faltar, o agente para
# em vez de cair silenciosamente no fluxo legado.
twm_play_priority_loader() {
    for _v2 in priority.sh state.sh action_runner.sh resource_guard.sh; do
        if [ ! -f "$TWMDIR/$_v2" ]; then
            printf "ERRO V2: modulo obrigatorio ausente: %s\n" "$_v2"
            unset _v2
            return 1
        fi
    done
    unset _v2

    if ! . "$TWMDIR/priority.sh"; then
        printf "ERRO V2: falha ao carregar priority.sh\n"
        return 1
    fi

    twm_play "$@"
}

twm_play() {
    twm_play_priority_loader "$@"
}
