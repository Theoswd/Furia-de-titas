twm_play() {
    # CORRECAO (multi-contas): antes gravava em "$HOME/twm/runmode_file".
    # Esse diretorio nao existe no layout multi-contas (que usa $HOME/.twm/<conta>),
    # entao a escrita falhava silenciosamente a cada ciclo. Pior: o cave.sh
    # gravava em "$TWMDIR/runmode_file" — arquivo UNICO compartilhado por todas
    # as contas, de modo que uma conta saindo do modo caverna trocava o modo
    # de todas as outras. Agora o runmode e por conta, dentro de $TMP.
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null

    if [ ! -s "$TMP/CLD" ]; then
        clan_id
    fi

    case `date +%H:%M` in
        (00:[0-5]5|01:[0-5]5|02:[0-5]5|03:[0-5]5)
            coliseum_fight
            ;;
        (00:00|00:30|01:00|01:30|02:00|02:30|03:00|03:30|04:00|04:30|05:00|05:30|06:00|06:30|07:00|07:30|08:00|08:30|09:00|11:30|12:00|13:00|13:30|14:30|15:30|17:00|17:30|18:00|18:30|19:30|20:00|20:30|23:00)
            start
            ;;
        (23:30)
            # CORRECAO (seguranca — SEC-01): a chamada automatica a update()
            # foi REMOVIDA daqui. Ela baixava e sobrescrevia play.sh, twm.sh,
            # info.sh e outros a partir de um repositorio de TERCEIRO
            # de terceiro, sem assinatura, sem checksum e sem
            # curl --fail — ou seja, execucao de codigo arbitrario diaria, e
            # substituicao dos arquivos do modelo multi-contas pelos do modelo
            # de conta unica. Para atualizar, use "git pull" revisando o diff.
            start
            ;;
        (09:5[5-9]|15:5[5-9]|21:5[5-9])
            undying_start
            start
            ;;
        (10:1[0-4]|16:1[0-4])
            flagfight_start
            ;;
        (10:2[8-9]|14:5[8-9])
            if [ -n "$CLD" ]; then
                clancoliseum_start
            fi
            start
            ;;
        (10:5[5-9]|18:5[5-9])
            if [ -n "$CLD" ]; then
                clanfight_start
            fi
            start
            ;;
        (12:2[5-9]|16:2[5-9]|22:2[5-9])
            king_start
            start
            ;;
        (13:5[5-9]|20:5[5-9])
            if [ -n "$CLD" ]; then
                altars_start
            fi
            start
            ;;
        (09:2[5-9]|21:2[5-9])
            specialEvent
            start
            ;;
        (*)
            if echo "$RUN" | grep -q -E '[-]cl'; then
                printf "Running in coliseum mode: %s\n" "$RUN"
                sleep 5
                arena_duel
                coliseum_start
                messages_info
            fi
            func_sleep
            func_crono
            ;;
    esac
}

# Reinicia APENAS esta conta.
#
# CORRECAO (multi-contas): a versao anterior fazia
#     pgrep -f "sh.*twm/twm.sh"  +  kill -9
# O padrao nao casava com o diretorio real do repositorio, entao nao matava
# nada; mas quem instalasse numa pasta chamada "twm" mataria TODAS as contas
# de uma vez. Em seguida chamava "$HOME/twm/twm.sh", caminho inexistente.
# Alem disso "kill -9 $pidf" com varios PIDs entre aspas e argumento invalido.
#
# Agora simplesmente encerra este processo: o worker.sh desta conta ja tem
# um laco que o reinicia em ~15s, sem tocar nas demais contas.
restart_script() {
    printf "[%s] %s — reiniciando esta conta\n" "$TWM_TAG" "${ACC:-$TWM_USER}"
    exit 0
}
