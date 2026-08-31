# shellcheck disable=SC2148
king_fight() {
  cd "$TMP" || return 1
  # LA = intervalo unico entre QUALQUER acao (ataque, erva, pedra, cura).
  # O jogo recusa uma acao que venha menos de ~4-5s depois da anterior, entao
  # ataque, erva e pedra compartilham o MESMO relogio: um por vez, a cada 5s.
  LA=5
  HPER="38"
  RPER=5

  # LEITURA DA PAGINA: DE 23 PROCESSOS PARA 2.
  #
  # Esta funcao lia o MESMO arquivo 23 vezes — sete grep, nove sed, dois awk
  # e cinco "$(cat ...)" — e roda duas a tres vezes por volta do laco de
  # luta. Davam 50 a 70 processos por volta, por conta, com todas as contas
  # entrando no evento no mesmo minuto. E o que estourava o teto de 32
  # processos do Android 12 e trazia o "signal 9" de volta justamente em
  # evento.
  #
  # Agora um unico awk le a pagina uma vez e grava os mesmos arquivos, com o
  # mesmo conteudo — conferido byte a byte em cinco cenarios: luta completa,
  # sem kingatk/stone, luta encerrada, pagina vazia e HP ausente.
  #
  # Sobram dois processos: o awk e o grep do nome do alvo, que continua
  # separado por depender de "sed -n 2p" com substituicoes proprias.
  cl_access() {
    set -- `combate_ler king "$HPER" "$RPER" "$TMP/SRC"`
    _emluta="$1"; RHP="$2"; HLHP="$3"; _hpat="$4"; _hp2at="$5"
    grep -o -E '([[:upper:]][[:lower:]]{0,15}( [[:upper:]][[:lower:]]{0,13})?)[[:space:]][^[:alnum:][:space:]]' "$TMP/SRC" | sed -n 's,\ [<]s,,;s,\ ,_,;2p' > USER 2>/dev/null
    if [ "$_emluta" = "1" ]; then
      # A pagina respondeu com a luta: sessao confirmada.
      sessao_marcar
      printf "Em batalha - HP: %s\n" "$_hpat"
    else
      (
        run_curl_exec "${URL}/king" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      grep -o -E '(/king/unrip/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC" | sed -n 1p > UNRIP 2>/dev/null
      if grep -q -o -E '(/king/unrip/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
        (
          run_curl_exec "${URL}$(cat UNRIP)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
      else
        echo 1 > BREAK_LOOP
        printf "Battle over.\n"
        sleep 3s
      fi
    fi
  }

  # ============================================================
  #  LACO DE LUTA DO REI — UM GOLPE POR CICLO, 4 A 5 SEGUNDOS
  #
  #  ANALISE DO QUE HAVIA ANTES (causava golpe perdido no jogo):
  #   1. No modo normal sem kingatk, disparava ATKRND e logo ATK no MESMO
  #      ciclo (~2s de intervalo) — o segundo golpe saia abaixo de 4s e o
  #      jogo nao o aceitava.
  #   2. O ramo de espera recarregava /king a cada ~1,5s — cada atualizacao
  #      de pagina em menos de 4s atrapalha o proximo golpe.
  #   3. O last_atk era marcado no FIM do request, somando o tempo do golpe
  #      em cima da recarga (intervalo real ~6-7s, lento demais).
  #   4. Nao usava a erva (GRASS); so a pedra (STONE).
  #   5. Os modos "sniper" spammavam 3 ataques sem intervalo (todos <4s).
  #
  #  AGORA — RELOGIO UNICO DE ACOES (LA = 5s):
  #  O jogo recusa qualquer acao que venha menos de ~4-5s depois da anterior
  #  (o golpe/ item "falha" e nao acerta). Por isso ATAQUE, ERVA, PEDRA e CURA
  #  compartilham UM SO relogio (_last_act): sai UMA acao por vez, a cada 5s.
  #  A cada janela de 5s escolhe-se UMA acao, nesta prioridade:
  #     1) CURA (esmalte) — so com a vida baixa (recarga propria de 90s);
  #     2) ERVA  — so quando disponivel (link na pagina);
  #     3) PEDRA — so quando disponivel (link na pagina);
  #     4) ATAQUE — kingatk (golpe forte), senao o ataque normal.
  #  Assim o intervalo ataque->erva, erva->pedra, pedra->ataque etc. e sempre
  #  ~5s, seguindo a mesma logica do ataque — nunca duas acoes coladas (<4s).
  #  O _last_act e marcado no INICIO da acao, para o tempo do request contar
  #  DENTRO do intervalo em vez de somar-se a ele. Dentro dos 5s o bot so
  #  espera, SEM nenhuma requisicao (uma atualizacao de pagina <5s tambem
  #  atrapalharia a proxima acao).
  #
  #  ERVA/PEDRA: usadas so quando o jogo mostra o link (mesma base dos outros
  #  modulos: arquivo GRASS/STONE nao-vazio = item disponivel). Nao estao
  #  presas ao botao de ataque nem a cura — sao acoes proprias no relogio.
  #
  #  ESQUIVA: no rei ela ocorre SO APOS A MORTE do rei (bloco pos-morte, no
  #  fim da funcao), para garantir a posicao na proxima rodada. Nao ha esquiva
  #  durante o combate — e assim de proposito.
  # ============================================================
  cl_access
  _agora=`date +%s`
  _last_heal=$(( _agora - 90 ))
  _last_act=$(( _agora - LA ))       # relogio unico das acoes (ataque/erva/pedra/cura)
  # old_HP gravado uma vez para o painel mostrar o dano acumulado da luta.
  echo "$_hpat"      > old_HP
  echo "$_last_heal" > last_heal
  echo "$_last_act"  > last_atk      # o painel le last_atk como "ultima acao"
  : > BREAK_LOOP

  # Teto de 10 min: BREAK_LOOP so e gravado quando a luta termina. Sem isso,
  # se o estado nunca resolver, o laco requisitaria para sempre.
  FIGHT_BREAK=$(( _agora + 600 ))
  until [ -s "BREAK_LOOP" ] || [ "`date +%s`" -gt "$FIGHT_BREAK" ]; do
    _agora=`date +%s`

    # RELOGIO UNICO: so age uma vez a cada LA (5s). Qualquer acao (ataque,
    # erva, pedra, cura) antes disso "falha" no jogo, entao todas esperam o
    # mesmo intervalo. Dentro dos 5s o bot so espera, sem NENHUMA requisicao.
    if [ $(( _agora - _last_act )) -ge "$LA" ]; then

      # PRIORIDADE 1 — CURA (esmalte): vida baixa cura primeiro, para a conta
      # nao morrer (tem recarga propria de 90s). O HP maximo (FULL, do /train)
      # NUNCA e sobrescrito pelo HP atual pos-cura.
      if awk -v ush="$_hpat" -v hlhp="$HLHP" 'BEGIN { exit !(ush < hlhp) }' && \
         [ $(( _agora - _last_heal )) -gt 90 ] && \
         [ $(( _agora - _last_heal )) -lt 300 ]; then
        (
          run_curl_exec "${URL}$(cat HEAL)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_heal="$_agora"; echo "$_last_heal" > last_heal
        _last_act="$_agora";  echo "$_last_act"  > last_atk

      # PRIORIDADE 2 — ERVA: acao propria, SO quando disponivel (link na
      # pagina = arquivo GRASS nao-vazio). Nao esta presa ao ataque nem a cura.
      elif [ -s GRASS ]; then
        (
          run_curl_exec "${URL}$(cat GRASS)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_act="$_agora"; echo "$_last_act" > last_atk

      # PRIORIDADE 3 — PEDRA: acao propria, SO quando disponivel (STONE nao-vazio).
      elif [ -s STONE ]; then
        (
          run_curl_exec "${URL}$(cat STONE)" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_act="$_agora"; echo "$_last_act" > last_atk

      # PRIORIDADE 4 — ATAQUE: kingatk preferido (golpe forte no rei), senao o
      # ataque normal. So quando o alvo NAO esta grey (invulneravel).
      elif ! grep -q -o 'txt smpl grey' "$TMP/SRC"; then
        if [ -s KINGATK ] && \
           grep -q -o -E '(king/kingatk/[^A-Za-z0-9_]r[^A-Za-z0-9_][0-9]+)' "$TMP/SRC"; then
          (
            run_curl_exec "${URL}$(cat KINGATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
        else
          (
            run_curl_exec "${URL}$(cat ATK)" > "$TMP/SRC"
          ) </dev/null > /dev/null 2>&1 &
          time_exit 17
          cl_access
        fi
        # Marca o INICIO da acao (nao o fim do request): o intervalo ate a
        # proxima acao fica em ~LA (5s), sem inflar com o tempo do request.
        _last_act="$_agora"; echo "$_last_act" > last_atk

      else
        # Alvo grey (invulneravel) e sem cura/item a fazer: rele a pagina para
        # ver quando o rei libera. Conta como o turno do relogio (5s), para
        # nao virar atualizacao em rajada (<5s tambem atrapalha).
        (
          run_curl_exec "${URL}/king" > "$TMP/SRC"
        ) </dev/null > /dev/null 2>&1 &
        time_exit 17
        cl_access
        _last_act="$_agora"; echo "$_last_act" > last_atk
      fi

    else
      # Dentro do intervalo de 5s: espera o restante SEM nenhuma requisicao —
      # uma atualizacao de pagina antes de 5s atrapalharia a proxima acao.
      _resta=$(( LA - ( _agora - _last_act ) ))
      [ "$_resta" -gt 0 ] && sleep "$_resta"
    fi

  done

  # ── POS-MORTE DO REI ───────────────────────────────────────────────────────
  # Executa dodge UMA ÚNICA VEZ imediatamente apos o rei morrer
  # Objetivo: garantir posicao para proxima rodada
  if [ -s DODGE ]; then
    printf "King morto — executando dodge pos-morte\n"
    (
      run_curl_exec "${URL}$(cat DODGE)" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
  fi

  unset cl_access
  func_unset
  # CORRECAO: sem o argumento, o apply_event monta "/${1}/" com $1
  # vazio e pede "//" — um request invalido que ainda gravava "//"
  # como atividade da conta no painel.
  apply_event king
  printf "King ok\n"
  sleep 10s
  [ -t 1 ] && clear
}

king_start() {
  case `date +%H:%M` in
  (12:2[5-9]|16:2[5-9]|22:2[5-9])
    (
      run_curl_exec "$URL/train" | grep -o -E '\(([0-9]+)\)' | sed 's/[()]//g' > "$TMP/FULL"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    (
      run_curl_exec "$URL/king/enterGame" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "King of the Immortals will be started...\n"
    until (case `date +%M` in (2[5-9]) exit 1;; esac); do
      sleep 3
    done
    (
      run_curl_exec "$URL/king/enterGame" > "$TMP/SRC"
    ) </dev/null > /dev/null 2>&1 &
    time_exit 17
    printf "\nKing\n%s\n" "$URL"
    link_acao "$TMP/SRC" king > "$TMP/ACCESS" 2>/dev/null
    printf " Entering...\n%s\n" "`cat "$TMP/ACCESS"`"
    printf " Waiting...\n"
    cat "$TMP/SRC" | grep -o 'king/kingatk/' > "$TMP/EXIT" 2>/dev/null
    BREAK=$(($(date +%s) + 30))
    until [ -s "$TMP/EXIT" ] || [ "$(date +%s)" -gt "$BREAK" ]; do
      printf " ...\n%s\n" "`cat "$TMP/ACCESS"`"
      (
        run_curl_exec "${URL}$(cat "$TMP/ACCESS")" > "$TMP/SRC"
      ) </dev/null > /dev/null 2>&1 &
      time_exit 17
      cat "$TMP/SRC" | sed 's/href=/\n/g' | grep '/king/' | head -n 1 | awk -F"[']" '{ print $2 }' > "$TMP/ACCESS" 2>/dev/null
      cat "$TMP/SRC" | grep -o 'king/kingatk/' > "$TMP/EXIT" 2>/dev/null
      sleep 2
    done
    king_fight
    ;;
  esac
}
