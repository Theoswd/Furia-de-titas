#!/bin/sh
# panel_live.sh - camada LIVE do painel.
#
# Regra: a coluna de atividade NAO usa scheduler, priority_state ou apelidos
# internos do bot. A unica fonte e $TMP/pagina, gravado por info.sh a cada
# requisicao real feita pela conta. O rotulo e apenas a area correspondente
# ao caminho atual do jogo, no mesmo sentido usado pelas paginas /online/.

pagina_nome_online() {
    _po="$1"
    [ -n "$_po" ] || _po="/"

    # A ordem importa: /clandungeon, /clanfight etc. precisam ser tratados
    # antes do prefixo generico /clan.
    case "$_po" in
        "/"|"/?out_gate_confirm=true"|"/?out_gate_confirm=true"*) _PO_NOME="Página Principal" ;;
        "/?sign_in=1"*)     _PO_NOME="Entrando" ;;
        /online*)            _PO_NOME="Online" ;;
        /clandungeon*)       _PO_NOME="Masmorra" ;;
        /clandmgfight*)      _PO_NOME="Duelo do Clã" ;;
        /clanfight*)         _PO_NOME="Torneio dos Clãs" ;;
        /clancoliseum*)      _PO_NOME="Coliseu do Clã" ;;
        /clan*)              _PO_NOME="Clã" ;;
        /fights*)            _PO_NOME="Cronograma de Batalhas" ;;
        /arena*)             _PO_NOME="Arena" ;;
        /career*)            _PO_NOME="Carreira" ;;
        /cave*)              _PO_NOME="Caverna" ;;
        /campaign*)          _PO_NOME="Campanha" ;;
        /coliseum*)          _PO_NOME="Coliseu" ;;
        /altars*)            _PO_NOME="Altares" ;;
        /undying*)           _PO_NOME="Vale dos Imortais" ;;
        /king*)              _PO_NOME="Rei dos Imortais" ;;
        /flagfight*)         _PO_NOME="Batalha de Bandeiras" ;;
        /league*)            _PO_NOME="Liga" ;;
        /trade*)             _PO_NOME="Troca" ;;
        /effshop*|/lab*)     _PO_NOME="Laboratório" ;;
        /quest*)             _PO_NOME="Missões" ;;
        /collector*)         _PO_NOME="Coleções" ;;
        /relic*)             _PO_NOME="Relíquias" ;;
        /sage*)              _PO_NOME="Cabana do Sábio" ;;
        /inv*)               _PO_NOME="Inventário" ;;
        /train*)             _PO_NOME="Treino" ;;
        /fault*)             _PO_NOME="Falha" ;;
        /collfight*)         _PO_NOME="Batalha Coletiva" ;;
        /marathon*)          _PO_NOME="Maratona" ;;
        /user*)              _PO_NOME="Herói" ;;
        /settings*)          _PO_NOME="Configurações" ;;
        /mail*)              _PO_NOME="Mensagens" ;;
        /questrnd*)          _PO_NOME="Missão Aleatória" ;;
        /logout*)            _PO_NOME="Saindo" ;;
        *)                   _PO_NOME="Página" ;;
    esac
}

aba_de() {
    _d="$1"
    ler_arq "$_d/pagina"; _p="$_LIDO"
    [ -n "$_p" ] || _p="/"

    pagina_nome_online "$_p"

    # Mostra somente a localizacao atual. O caminho bruto continua disponivel
    # em ~/.twm/BR_<conta>/pagina para diagnostico, mas nao polui o painel.
    if [ "$_p" = "/" ] || [ "$_p" = "/?out_gate_confirm=true" ]; then
        printf '○ %s' "$_PO_NOME"
    else
        printf '● LIVE %s' "$_PO_NOME"
    fi
    unset _d _p _PO_NOME
}

# Relatorio de combate somente enquanto a conta ESTA numa pagina de batalha.
# HP/old_HP podem permanecer no disco depois da luta; por isso nunca usamos a
# mera existencia desses arquivos como prova de combate ativo.
combate_de() {
    _d="$1"
    ler_arq "$_d/pagina"; _p="$_LIDO"

    case "$_p" in
        /coliseum*)
            # No Coliseu o relatorio transitorio e a prova adicional de que a
            # luta atual ainda esta ativa. coliseum.sh o apaga ao terminar.
            [ -s "$_d/col_report" ] || { unset _d _p; return 0; }
            ;;
        /clanfight*|/clancoliseum*|/clandmgfight*|/flagfight*|/altars*|/undying*|/king*|/collfight*)
            ;;
        *)
            unset _d _p
            return 0
            ;;
    esac

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
        # Pega a ultima linha usando apenas builtins do shell. Evita criar um
        # processo tail por conta a cada redesenho, importante no Android.
        _acao=""
        while IFS= read -r _linha; do
            [ -n "$_linha" ] && _acao="$_linha"
        done < "$_d/col_report"
        [ -n "$_acao" ] && _texto="${_texto:+$_texto  |  }LIVE: $_acao"
    fi

    printf '%s' "$_texto"
    unset _d _p _hp _old _dif _texto _acao _linha
}
