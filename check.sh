check_missions() {
    printf "Checking Missions\n"

    fetch_page "/quest/"

    for i in 1 2; do
        click=`grep -o -E "/quest/openChest/$i/[?]r=[0-9]+" "$TMP/SRC" | head -n1`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Chest %s opened\n" "$i"
        fi
    done

    if [ "$FUNC_collect_mission_rewards" = "n" ]; then
        return
    fi

    # CORRECAO: o laco de missoes lia $TMP/SRC, mas ao abrir os baus acima o
    # fetch_page ja tinha sobrescrito o SRC com a pagina de resultado do bau —
    # entao os links /quest/end/ eram procurados na pagina errada e as missoes
    # concluidas nao eram recolhidas. Rebusca a pagina de missoes (que ja
    # reflete o estado apos abrir os baus).
    fetch_page "/quest/"

    i=0
    while [ "$i" -le 16 ]; do
        click=`grep -o -E "/quest/end/${i}[?]r=[0-9]+" "$TMP/SRC" | sed -n '1p'`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Mission %s Completed\n" "$i"
        fi
        i=$((i + 1))
    done

    fetch_page "/collector/"
    click=`grep -o -E "/collector/reward/element/[?]r=[0-9]+" "$TMP/SRC"`
    if [ -n "$click" ]; then
        fetch_page "$click"
        printf "Collection collected\n"
    fi

    printf "Missions ok\n"
}

check_rewards() {
    if [ "$FUNC_check_rewards" = "n" ]; then
        return
    fi

    fetch_page "/relic/reward/"

    i=0
    while [ "$i" -le 11 ]; do
        click=`grep -o -E "/relic/reward/${i}/[?]r=[0-9]+" "$TMP/SRC"`
        if [ -n "$click" ]; then
            fetch_page "$click"
            printf "Relic %s collected\n" "$i"
        fi
        i=$((i + 1))
    done
}

apply_event() {
    event_path="${1}"
    fetch_page "/${event_path}/"
    if grep -o -E "/${event_path}/enter(Game|Fight)/[?]r=[0-9]+" "$TMP/SRC"; then
        APPLY=`grep -o -E "/${event_path}/enter(Game|Fight)/[?]r=[0-9]+" "$TMP/SRC"`
        fetch_page "$APPLY"
        printf "Applied for battle\n"
    fi
}

use_elixir() {
    if [ "$FUNC_use_elixir" = "n" ]; then
        return
    fi

    # CORRECAO: pegava o i-esimo link (`sed -n "${i}p"`) de uma pagina que
    # muda a cada uso — os indices desalinhavam apos o primeiro elixir — e
    # reaproveitava o nonce `?r=` da PRIMEIRA leitura, que o servidor pode
    # recusar. Agora rebusca a pagina a cada volta (nonce fresco) e usa sempre
    # o PRIMEIRO link disponivel; quando nao ha mais, encerra.
    i=1
    while [ "$i" -le 4 ]; do
        fetch_page "/inv/chest/"
        click=`grep -o -E "/inv/chest/use/[0-9]+/1/[?]r=[0-9]+" "$TMP/SRC" | sed -n 1p`
        if [ -z "$click" ]; then
            printf "No more URLs to process.\n"
            break
        fi
        fetch_page "$click"
        i=$((i + 1))
    done

    printf "Applied all elixir\n"
}
