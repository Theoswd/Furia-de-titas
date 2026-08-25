# Global variable to control loop exits
EXIT_CONFIG="n"

update_config() {
    key="$1"
    value="$2"

    if [ ! -f "$CONFIG_FILE" ]; then
        printf "Configuration file not found. Creating new...\n"
        touch "$CONFIG_FILE"
    fi

    if grep -q "^${key}=" "$CONFIG_FILE"; then
        set_config "$key" "$value"
        printf "Configuration %s updated to %s.\n" "$key" "$value"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
        printf "Added new configuration key %s with value %s.\n" "$key" "$value"
    fi
}

request_update() {
    key=""
    value=""
    success=1

    while [ "$success" -ne 0 ]; do
        printf "  Macro settings - type option number:\n"
        printf " 1- Collect relics. Current: %s\n" "$FUNC_check_rewards"
        printf " 2- Use elixir. Current: %s\n" "$FUNC_use_elixir"
        printf " 3- Auto update. Current: %s\n" "$FUNC_AUTO_UPDATE"
        printf " 4- Get to top in league. Current: %s\n" "$FUNC_play_league"
        printf " 5- Change language. Current: %s\n" "$LANGUAGE"
        printf " 6- Change allies. Current: %s\n" "$ALLIES"
        printf " 7- Collect mission rewards. Current: %s\n" "$FUNC_collect_mission_rewards"
        printf " 8- Pause mission rewards on weekends. Current: %s\n" "$FUNC_pause_weekends"
        printf " 9- Complete events. Current: %s\n" "$FUNC_auto_events"
        printf " A- Complete clan missions. Current: %s\n" "$FUNC_clan_missions"
        printf " B- Enable clan statue automatically. Current: %s\n" "$FUNC_clan_statue"
        printf " C- Cave gold boost: DISABLED BY POLICY\n"
        printf " Press ENTER to exit.\n"

        read -r key

        case $key in
            1) printf "Collect the relics (y or n): "; key="FUNC_check_rewards" ;;
            2) printf "Use elixir before all valleys? (y or n): "; key="FUNC_use_elixir" ;;
            3) printf "Update the script automatically? (y or n): "; key="FUNC_AUTO_UPDATE" ;;
            4)
                printf "League number to reach the top (1-999): "
                while true; do
                    read -r value
                    case "$value" in
                        [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) set_config "FUNC_play_league" "$value"; break ;;
                        *) printf "Invalid input. Enter a number between 1 and 999: " ;;
                    esac
                done
                key="FUNC_play_league"
                ;;
            5)
                printf "Language is managed by language_setup.\n"
                continue
                ;;
            6)
                printf "Change your allies for battle? (y or n): "
                while true; do
                    read -r value
                    echo
                    case "$value" in [yYnN]) break ;; *) printf "Invalid input. Enter 'y' or 'n': " ;; esac
                done
                if [ "$value" != "n" ]; then
                    set_config "ALLIES" ""
                    key="ALLIES"
                    : > "$TMP/allies.txt"
                    : > "$TMP/callies.txt"
                    conf_allies
                fi
                break
                ;;
            7) printf "Collect mission rewards automatically? (y or n): "; key="FUNC_collect_mission_rewards" ;;
            8) printf "Pause mission rewards on weekends? (y or n): "; key="FUNC_pause_weekends" ;;
            9) printf "Run special events? (y or n): "; key="FUNC_auto_events" ;;
            a|A) printf "Complete the clan missions? (y or n): "; key="FUNC_clan_missions" ;;
            b|B) printf "Enable clan statue automatically? (y or n): "; key="FUNC_clan_statue" ;;
            c|C)
                set_config "FUNC_cave_boost" "n"
                FUNC_cave_boost=n
                printf "Cave gold boost remains disabled.\n"
                continue
                ;;
            *) printf "Exiting configuration update mode.\n"; EXIT_CONFIG="y"; return ;;
        esac

        case "$key" in
            FUNC_*)
                while true; do
                    read -r value
                    echo
                    case "$value" in [yYnN]) break ;; *) printf "Invalid input. Please enter 'y' or 'n': " ;; esac
                done
                update_config "$key" "$value"
                success=$?
                if [ "$success" -ne 0 ]; then
                    printf "Invalid key. Please try again.\n"
                else
                    printf "Configuration updated successfully!\n"
                    config
                    break
                fi
                ;;
        esac
    done
}

config_defaults() {
    cat <<'EOF'
FUNC_check_rewards=y
FUNC_use_elixir=y
FUNC_use_blessing=n
FUNC_blessing_gold_min=100
FUNC_trade=y
FUNC_trade_dias=365
FUNC_coliseum=y
FUNC_AUTO_UPDATE=n
FUNC_play_league=999
FUNC_clan_figth=y
FUNC_collect_mission_rewards=y
FUNC_pause_weekends=n
FUNC_auto_events=y
FUNC_clan_missions=y
FUNC_clan_quests=y
FUNC_clan_help=y
FUNC_quest_force_gold=n
FUNC_quest_gold_min=2000
FUNC_arena_min=30
FUNC_arena_sell_all=n
FUNC_cq_min=15
FUNC_masmorra=y
FUNC_estatua_horas=6
FUNC_stats_min=3
FUNC_clan_statue=y
FUNC_cave_boost=n
SCRIPT_PAUSED=n
ALLIES=
EOF
}

load_config() {
    CONFIG_FILE="${TMP:-.}/config.cfg"
    [ -f "$CONFIG_FILE" ] || : > "$CONFIG_FILE"

    config_defaults | while IFS='=' read -r _dk _dv; do
        [ -n "$_dk" ] || continue
        grep -q "^${_dk}=" "$CONFIG_FILE" 2>/dev/null || printf '%s=%s\n' "$_dk" "$_dv" >> "$CONFIG_FILE"
    done

    while IFS='=' read -r _ck _cv; do
        case "$_ck" in
            FUNC_*|LANGUAGE|ALLIES|SCRIPT_PAUSED|CAVE_GOLD_LIMIT|CAVE_SILVER_LIMIT) ;;
            *) continue ;;
        esac
        case "$_cv" in *[!A-Za-z0-9_.:/-]*) continue ;; esac
        eval "${_ck}=\"\$_cv\""
    done < "$CONFIG_FILE"

    # Regras absolutas: configs antigos nao podem reativar estes gastos.
    FUNC_use_blessing=n
    FUNC_cave_boost=n
    FUNC_quest_force_gold=n
    export FUNC_use_blessing FUNC_cave_boost FUNC_quest_force_gold

    unset _ck _cv _dk _dv
}

get_config() {
    _gc_key="$1"
    load_config
    grep -E "^${_gc_key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-
}

set_config() {
    key="$1"
    value="$2"
    load_config

    case "$key" in
        FUNC_use_blessing|FUNC_cave_boost|FUNC_quest_force_gold) value=n ;;
    esac

    grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "${key}=${value}" >> "$CONFIG_FILE"
}

config() {
    load_config
    EXIT_CONFIG="n"

    while true; do
        if [ "$EXIT_CONFIG" = "n" ]; then
            printf "Script paused. Waiting for reactivation...\n"
            sleep 1
            request_update
        else
            printf "Exiting configuration update mode...\n"
            EXIT_CONFIG="n"
            sleep 1
            break
        fi
    done
}

# Nao altera permanentemente a preferencia de coleta. Apenas calcula o estado
# runtime, evitando o bug em que o bot desligado na segunda 00:00 nunca
# reativava a opcao escrita no arquivo.
pause_missions_weekend() {
    COLLECT_REWARDS_RUNTIME="${FUNC_collect_mission_rewards:-n}"
    [ "${FUNC_pause_weekends:-n}" = "y" ] || { export COLLECT_REWARDS_RUNTIME; return 0; }

    current_day=`date +%u`
    case "$current_day" in 6|7) COLLECT_REWARDS_RUNTIME=n ;; esac
    export COLLECT_REWARDS_RUNTIME
}
