twm_play() {
    echo "$RUN" > "$TMP/runmode_file" 2>/dev/null

    if [ ! -s "$TMP/CLD" ]; then
        clan_id
    fi

    # ORDEM DE PRIORIDADE DOS EVENTOS
    #
    # O "case" para no primeiro padrao que casa, entao a ordem dos ramos
    # E a prioridade. De cima para baixo:
    #
    #   1. Torneio dos Clas      10:55  18:55
    #   2. Altares dos Deuses    13:55  20:55
    #   3. Vale dos Imortais     09:55  15:55  21:55
    #   4. Rei dos Imortais      12:25  16:25  22:25
    #   5. Coliseu do Cla        10:28  14:58
    #
    # O Coliseu comum roda das 00:30 as 04:30 em todas as contas.
    case `date +%H:%M` in

        # --- 1. Torneio dos Clas
        (10:5[5-9]|18:5[5-9])
            if [ -n "$CLD" ]; then
                clanfight_start
            fi
            start
            ;;

        # --- 2. Altares dos Deuses
        (13:5[5-9]|20:5[5-9])
            if [ -n "$CLD" ]; then
                altars_start
            fi
            start
            ;;

        # --- 3. Vale dos Imortais
        (09:5[5-9]|15:5[5-9]|21:5[5-9])
            undying_start
            start
            ;;

        # --- 4. Rei dos Imortais
        (12:2[5-9]|16:2[5-9]|22:2[5-9])
            king_start
            start
            ;;

        # --- 5. Coliseu do Cla
        (10:2[8-9]|14:5[8-9])
            if [ -n "$CLD" ]; then
                clancoliseum_start
            fi
            start
            ;;

        # --- Coliseu comum: 00:30 as 04:30
        (00:3[0-9]|00:[45][0-9]|0[123]:[0-5][0-9]|04:[0-2][0-9]|04:30)
            coliseum_fight
              # PAUSA PARA CHECAR MISSOES. O Coliseu comum nao esta entre os
              # cinco eventos de prioridade, entao entre as lutas o bot
              # confere o checklist do cla e roda a arena no intervalo dela.
              # Antes, as quatro horas da janela passavam sem nada disso.
            tarefas_livres
            ;;

        # --- Batalha de Bandeiras
        (10:1[0-4]|16:1[0-4])
            flagfight_start
            ;;

        # --- Eventos especiais
        (09:2[5-9]|21:2[5-9])
            specialEvent
            start
            ;;

        # --- Rotina comum
        (00:00|01:00|02:00|03:00|04:3[1-9]|05:00|05:30|06:00|06:30|07:00|07:30|08:00|08:30|09:00|11:00|11:30|12:00|13:00|13:30|14:00|14:30|15:00|15:30|17:00|17:30|18:00|18:30|19:00|19:30|20:00|20:30|22:00|23:00|23:30)
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
            # Arena a cada 30 min, mesmo fora dos minutos da agenda.
            tarefas_livres
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
