# shellcheck disable=SC2034
fetch_available_fights() {
    fetch_page "/league/" "$TMP/LEAGUE_SRC"

    if [ -f "$TMP/LEAGUE_SRC" ]; then
        printf "Looking for available fights...\n"
        AVAILABLE_FIGHTS=`grep -o -E '<b>[0-5]</b>' "$TMP/LEAGUE_SRC" | head -n 1 | sed -n 's/.*<b>\([0-5]\)<\/b>.*/\1/p'`

        case "$AVAILABLE_FIGHTS" in
            [0-5])
                printf "Available fights: %s\n" "$AVAILABLE_FIGHTS"
                ;;
            *)
                printf "Error: No available fights or not found.\n" >> "$TMP/ERROR_DEBUG"
                AVAILABLE_FIGHTS=0
                ;;
        esac
    else
        printf "The LEAGUE_SRC file was not found.\n" >> "$TMP/ERROR_DEBUG"
        AVAILABLE_FIGHTS=0
    fi

    AVAILABLE_FIGHTS=${AVAILABLE_FIGHTS:-0}
    [ "$AVAILABLE_FIGHTS" -gt 0 ]
}

get_enemy_stat() {
    index=$1
    stat_num=$2
    attempts=0
    max_attempts=10

    while [ "$attempts" -lt "$max_attempts" ]; do
        stat=`grep -o -E ': [0-9]+' "$TMP/SRC" | sed -n "$((index + stat_num))s/: //p" | tr -d '()' | tr -d ' '`

        if [ -n "$stat" ] && [ "$stat" -gt 49 ]; then
            echo "$stat"
            return 0
        fi
        stat_num=$((stat_num + 1))
        attempts=$((attempts + 1))
    done

    printf "Error: Stat not found after %s attempts.\n" "$max_attempts" >> "$TMP/ERROR_DEBUG"
    return 1
}

# ---------------------------------------------------------------------------
#  RECOMPENSA DA LIGA DOS FAVORITOS — ESTADO SEPARADO DAS LUTAS
#
#  Concluir as cinco lutas NAO significa recompensa coletada. A recompensa
#  as vezes demora a aparecer, e liberar cinco lutas novas nao pode apagar o
#  estado pendente. Por isso "pendente" e um marcador em disco, por conta,
#  que sobrevive a reinicios do worker:
#
#     $TMP/league_reward_pending
#
#  A coleta so e dada como concluida quando o SERVIDOR confirma: o botao
#  takeReward some da pagina apos o clique. Enquanto nao confirma, o estado
#  fica pendente e a proxima passagem tenta de novo (recompensa atrasada).
#  A Liga nao fica travada esperando — o worker segue as outras atividades e
#  volta no proximo intervalo (portao de 30 min), que serve de nova tentativa
#  sem loop infinito.
# ---------------------------------------------------------------------------
league_reward_marcar()   { : > "$TMP/league_reward_pending" 2>/dev/null; }
league_reward_limpar()   { rm -f "$TMP/league_reward_pending" 2>/dev/null; }
league_reward_pendente() { [ -f "$TMP/league_reward_pending" ]; }

# Tenta coletar a recompensa e confirma pela resposta real do servidor.
#   retorno 0 = coleta confirmada (o botao sumiu)
#   retorno 1 = recompensa ainda indisponivel ou coleta nao confirmada
league_collect_reward() {
    fetch_page "/league/"
    _lr_click=`grep -o -E "/league/takeReward/\?r=[0-9]+" "$TMP/SRC" | sed -n 1p`
    if [ -z "$_lr_click" ]; then
        unset _lr_click
        return 1
    fi

    printf "[LIGA] Recompensa encontrada. Tentando coletar.\n"
    fetch_page "$_lr_click"

    # CONFIRMACAO REAL: recarrega a pagina; se o botao sumiu, o servidor
    # aceitou a coleta. So entao a recompensa e dada como recebida.
    fetch_page "/league/"
    if grep -q -o -E "/league/takeReward/\?r=[0-9]+" "$TMP/SRC"; then
        printf "[LIGA] Falha ao coletar recompensa. Nova tentativa sera programada.\n"
        unset _lr_click
        return 1
    fi
    printf "[LIGA] Coleta confirmada pelo servidor.\n"
    unset _lr_click
    return 0
}

league_play() {
    printf "League\n"
    load_config
    checkQuest 2 apply
    checkQuest 1 apply

    PLAYER_STRENGTH=`player_stats`
    fetch_available_fights

    # Sem lutas na entrada = ciclo de cinco ja concluido numa passagem
    # anterior: ha (ou havera) recompensa. Marca como pendente para a coleta
    # nao depender do laco de lutas, que nem chega a rodar quando fights=0.
    if [ "${AVAILABLE_FIGHTS:-0}" -eq 0 ]; then
        league_reward_marcar
    fi

    # RECOMPENSA PENDENTE PRIMEIRO: coleta agora (inclui a recompensa que
    # apareceu atrasada apos uma passagem anterior) antes de qualquer luta.
    if league_reward_pendente; then
        printf "[LIGA] Verificando recompensa pendente.\n"
        if league_collect_reward; then
            league_reward_limpar
        else
            printf "[LIGA] Recompensa ainda indisponivel. Estado preservado como pendente.\n"
        fi
    fi

    action="check_fights"
    fights_done=0
    j=1
    enemy_index=1
    FUNC_play_league=`get_config "FUNC_play_league"`

    while [ "$AVAILABLE_FIGHTS" -gt 0 ]; do
        case "$action" in
            check_fights)
                fetch_page "/league/"
                click=`grep -o -E "/league/fight/[0-9]{1,3}/\?r=[0-9]{1,8}" "$TMP/SRC" | sed -n "${j}p"`

                if [ -n "$click" ]; then
                    ENEMY_NUMBER=`echo "$click" | grep -o -E '[0-9]+' | head -n 1`
                    INDEX=$(((enemy_index - 1) * 4))
                    E_STRENGTH=`get_enemy_stat "$INDEX" 1`
                    E_HEALTH=`get_enemy_stat "$INDEX" 2`
                    E_AGILITY=`get_enemy_stat "$INDEX" 3`
                    E_PROTECTION=`get_enemy_stat "$INDEX" 4`
                    printf "Enemy Number: %s\n" "$ENEMY_NUMBER"

                    if [ "$AVAILABLE_FIGHTS" -eq 0 ] && [ "$ENEMY_NUMBER" -gt "$FUNC_play_league" ]; then
                        printf "Refreshed fights\n"
                        click=`grep -o -E "/league/refreshFights/\?r=[0-9]+" "$TMP/SRC" | sed -n 1p`
                        fetch_page "$click"
                        enemy_index=1
                        j=1
                    fi
                    action="fight_or_skip"
                else
                    printf "No fight buttons found for button %s\n" "$j" >> "$TMP/ERROR_DEBUG"
                    action="exit_loops"
                fi
                ;;

            fight_or_skip)
                if [ "$PLAYER_STRENGTH" -gt "$E_STRENGTH" ] || [ -f "$TMP/POTION" ]; then
                    printf "Strength (%s) > enemy (%s). Fighting %s.\n" "$PLAYER_STRENGTH" "$E_STRENGTH" "$ENEMY_NUMBER"
                    fetch_page "$click"
                    fights_done=$((fights_done + 1))
                    enemy_index=1
                    j=1
                    last_click=`grep -o -E "/league/fight/[0-9]{1,3}/\?r=[0-9]{1,8}" "$TMP/SRC" | sed -n "${j}p"`
                    ENEMY_NUMBER=`echo "$last_click" | grep -o -E '[0-9]+' | head -n 1`
                    fetch_available_fights
                    action="check_fights"
                    if [ -f "$TMP/POTION" ]; then
                        rm "$TMP/POTION"
                    fi
                else
                    printf "Strength (%s) < enemy (%s). Skipping.\n" "$PLAYER_STRENGTH" "$E_STRENGTH"
                    enemy_index=$((enemy_index + 1))
                    j=$((j + 2))
                    last_click=`grep -o -E "/league/fight/[0-9]{1,3}/\?r=[0-9]{1,8}" "$TMP/SRC" | sed -n "${j}p"`
                    ENEMY_NUMBER=`echo "$last_click" | grep -o -E '[0-9]+' | head -n 1`
                    fetch_available_fights
                    if [ -z "$last_click" ] && [ "$AVAILABLE_FIGHTS" -gt 1 ]; then
                        printf "Reached the last enemy. Attacking and using a potion...\n"
                        j=$((j - 2))
                        click=`grep -o -E "/league/fight/[0-9]{1,3}/\?r=[0-9]{1,8}" "$TMP/SRC" | sed -n "${j}p"`
                        fetch_page "$click"
                        fights_done=$((fights_done + 1))
                        fetch_available_fights
                        sleep 1s
                        potion_click=`grep -o -E "/league/potion/\?r=[0-9]+" "$TMP/SRC" | sed -n 1p`
                        fetch_page "$potion_click"
                        printf "Used a potion\n"
                        echo "potion used" > "$TMP/POTION"
                        E_STRENGTH=50
                        enemy_index=1
                        j=1
                        action="check_fights"
                    else
                        action="check_fights"
                    fi
                fi
                ;;

            exit_loops)
                break
                ;;
        esac

        case "$AVAILABLE_FIGHTS" in
            *[!0-9]*)
                printf "Error: %s is not a valid number.\n" "$AVAILABLE_FIGHTS" >> "$TMP/ERROR_DEBUG"
                AVAILABLE_FIGHTS=0
                ;;
            *)
                if [ "$AVAILABLE_FIGHTS" -eq 0 ]; then
                    # Cinco lutas concluidas: ha recompensa a coletar. Apenas
                    # MARCA como pendente; a coleta (com confirmacao real) e
                    # feita fora do laco. Nunca deduzir "coletada" das lutas.
                    printf "[LIGA] Lutas concluidas. Recompensa pendente=sim.\n"
                    league_reward_marcar
                fi
                ;;
        esac
    done

    # COLETA DA RECOMPENSA — fora do laco de lutas.
    #
    # Chega aqui quem terminou as cinco lutas nesta passagem. Se ha recompensa
    # pendente, tenta coletar e confirma pelo servidor; so limpa o estado com a
    # confirmacao. Se a recompensa ainda nao apareceu, o marcador fica para a
    # proxima passagem — a Liga nao trava esperando e o worker segue as demais
    # atividades. Liberar cinco lutas novas NAO apaga este estado.
    if league_reward_pendente; then
        if league_collect_reward; then
            league_reward_limpar
        else
            printf "[LIGA] Recompensa ainda indisponivel. A instancia continuara outras atividades.\n"
        fi
    fi

    unset click ENEMY_NUMBER PLAYER_STRENGTH E_STRENGTH AVAILABLE_FIGHTS fights_done enemy_index j

    checkQuest 2 end
    checkQuest 1 end

    printf "League Routine Completed ok\n"
}
