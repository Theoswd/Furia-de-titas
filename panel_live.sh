#!/bin/sh
# panel_live.sh - camada de exibicao ao vivo, sem alterar o desenho base do panel.sh.
# O panel.sh continua responsavel pelo layout. Esta camada substitui somente
# as funcoes de sessao/combate para acrescentar o LED e a ultima acao da luta.

aba_de() {
    _d="$1"
    ler_arq "$_d/pagina"; _p="$_LIDO"
    [ -z "$_p" ] && _p="/"

    case "$_p" in
        /fights*) _nome="Agenda de Batalhas" ;;
        /arena*) _nome="Arena" ;;
        /career*) _nome="Carreira" ;;
        /cave*) _nome="Caverna" ;;
        /campaign*) _nome="Campanha" ;;
        /coliseum*) _nome="Coliseu" ;;
        /clancoliseum*) _nome="Coliseu do Clã" ;;
        /clanfight*) _nome="Torneio dos Clãs" ;;
        /clandungeon*|/clandmgfight*) _nome="Masmorra do Clã" ;;
        /clan/*quest*) _nome="Missões do Clã" ;;
        /clan/*built*) _nome="Estátua do Clã" ;;
        /clan*) _nome="Clã" ;;
        /altars*) _nome="Altares dos Deuses" ;;
        /undying*) _nome="Vale dos Imortais" ;;
        /king*) _nome="Rei dos Imortais" ;;
        /flagfight*) _nome="Batalha de Bandeiras" ;;
        /league*) _nome="Liga dos Favoritos" ;;
        /trade*) _nome="Troca" ;;
        /effshop*|/lab*) _nome="Aprimoramento" ;;
        /quest*) _nome="Missões" ;;
        /collector*) _nome="Coleções" ;;
        /relic*) _nome="Relíquias" ;;
        /sage*) _nome="Cabana do Sábio" ;;
        /inv*) _nome="Inventário" ;;
        /train*) _nome="Treino" ;;
        /fault*) _nome="Falha" ;;
        /collfight*) _nome="Batalha Coletiva" ;;
        /marathon*) _nome="Maratona" ;;
        /user*) _nome="Meu Herói" ;;
        /settings*) _nome="Configurações" ;;
        /mail*) _nome="Mensagens" ;;
        /questrnd*) _nome="Missão Aleatória" ;;
        /logout*) _nome="Saindo" ;;
        /|/?out_gate_confirm=true) _nome="Página Principal" ;;
        /?sign_in=1) _nome="Entrando" ;;
        *) _nome="Página" ;;
    esac

    if [ -n "$_p" ] && [ "$_p" != "/" ]; then
        _led="● LIVE"
    else
        _led="○ /"
    fi

    # Nome amigavel + LED + caminho exato da sessao.
    printf '%s %s [%s]' "$_led" "$_nome" "$_p"
    unset _d _p _nome _led
}

# Mantem o calculo de HP/dano do painel e acrescenta a ultima linha do
# historico da luta do Coliseu. A linha vem de $TMP/col_report e desaparece
# quando coliseum_fight termina.
combate_de() {
    _d="$1"
    ler_arq "$_d/HP"; _hp="$_LIDO"
    ler_arq "$_d/old_HP"; _old="$_LIDO"
    case "$_hp"  in ''|*[!0-9]*) _hp=""  ;; esac
    case "$_old" in ''|*[!0-9]*) _old="" ;; esac

    _texto=""
    if [ -n "$_hp" ]; then
        if [ "$_hp" -eq 0 ] 2>/dev/null; then
            _texto="VOCÊ ESTÁ MORTO"
        elif [ -n "$_old" ] && [ "$_old" -gt 0 ] 2>/dev/null; then
            _dif=$((_hp - _old))
            if [ "$_dif" -lt 0 ]; then
                _texto="HP $_hp  (${_dif#-} dano recebido)"
            elif [ "$_dif" -gt 0 ]; then
                _texto="HP $_hp  (+$_dif recuperado)"
            else
                _texto="HP $_hp"
            fi
        else
            _texto="HP $_hp"
        fi
    fi

    if [ -s "$_d/col_report" ]; then
        # O historico e regravado pelo worker a cada resposta do jogo. tail
        # aqui serve apenas para pegar a ultima acao; nao e mantido depois da
        # luta. Linhas como "Thaydark acertar Você" e "Você usou Turbilhão"
        # entram porque afetam diretamente a conta corrente.
        _acao=$(tail -n 1 "$_d/col_report" 2>/dev/null)
        [ -n "$_acao" ] && _texto="${_texto:+$_texto  |  }LIVE: $_acao"
    fi

    printf '%s' "$_texto"
    unset _d _hp _old _dif _texto _acao
}
