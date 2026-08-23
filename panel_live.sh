#!/bin/sh
# panel_live.sh - camada de sessao ao vivo, sem alterar o desenho base do panel.sh.
# O panel.sh continua responsavel pelo layout. Esta camada apenas substitui
# aba_de() depois que o painel foi carregado.

# O worker registra em $acc_dir/pagina o ultimo caminho realmente requisitado.
# Como run_curl/fetch_page passam por _rc_track, isso acompanha inclusive
# paginas especificas de uma atividade, em vez de mostrar somente um nome
# generico da secao.
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

    # LED de sessao: indica que a conta tem um caminho de sessao conhecido.
    # Se o worker estiver fora dessas rotas, ainda mostramos o caminho exato.
    # A informacao fica curta o suficiente para o painel continuar cabendo
    # com muitas contas.
    if [ -n "$_p" ] && [ "$_p" != "/" ]; then
        _led="● LIVE"
    else
        _led="○ /"
    fi

    # Nome amigavel + caminho exato da sessao. Nao consulta /online/ para
    # adivinhar a pagina: usa o estado real escrito pela propria conta.
    printf '%s %s [%s]' "$_led" "$_nome" "$_p"
    unset _d _p _nome _led
}
