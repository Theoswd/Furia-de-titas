#!/bin/sh
# panel_live.sh - camada de exibicao ao vivo, sem alterar o desenho do panel.sh.
# O panel.sh continua responsavel pelo layout; este arquivo apenas troca a
# fonte da informacao de sessao para o caminho real gravado pelo worker.

# Mostra o caminho requisitado pelo worker, nao somente um rotulo generico.
# Assim o painel consegue distinguir, por exemplo, /arena/ de
# /arena/attack/1/?r=123, enquanto preserva o nome amigavel.
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
        /|/?out_gate_confirm=true|/?sign_in=1) _nome="Página Principal" ;;
        *) _nome="Página" ;;
    esac

    # O painel existente usa esta string em uma coluna de largura limitada.
    # Mantemos o nome amigavel e anexamos o caminho exato em que a requisicao
    # da sessao esta acontecendo.
    printf '%s [%s]' "$_nome" "$_p"
    unset _d _p _nome
}

# Mantem o relatorio de HP/dano do panel.sh, mas acrescenta os eventos que
# forem registrados pelo battle_report.sh sem modificar o layout principal.
# O relatorio detalhado fica em menu separado para nao poluir o painel.
