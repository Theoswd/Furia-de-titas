#!/bin/sh
# resource_guard.sh - politica central de gasto automatico.
#
# Regra base: NEGAR o que nao estiver explicitamente permitido. Todo gasto
# passa por aqui e fica registrado em $TMP/resource_ledger, para que
# nenhuma funcao gaste recurso sem deixar rastro.
#
# Motivos previstos (secoes do prompt do agente):
#   blessing              bencao ................ NEGADO (decisao do dono)
#   clan_help_gold        ajudar missao com ouro . NEGADO (secao 6)
#   cave_gold_boost       acelerar caverna c/ ouro NEGADO (secao 9)
#   cave_mission_silver   acelerar caverna c/prata PERMITIDO se ligado a missao
#   career_gold_mission   acelerar carreira ...... PERMITIDO ate 100 de ouro,
#                                                  so com missao do cla e saldo
#                                                  anterior acima de 2000 (secao 8)
#   clan_treasury_gold    financiar ouro ......... PERMITIDO 10 por dia (secao 15)
#   clan_treasury_silver  financiar prata ........ PERMITIDO em dias alternados
#   statue_bonus          bonus da estatua ....... PERMITIDO ao lider (secao 4)

resource_log() {
    printf '%s|%s|%s|%s|%s\n' "$(date +%s)" "$1" "$2" "$3" "$4" \
        >> "$TMP/resource_ledger" 2>/dev/null
}

# resource_allow <recurso> <quantidade> <motivo> [saldo_atual]
resource_allow() {
    _rr="$1"; _ra="${2:-0}"; _rw="$3"; _rs="${4:-}"
    case "$_ra" in ''|*[!0-9]*) _ra=0 ;; esac
    case "$_rs" in ''|*[!0-9]*) _rs=0 ;; esac

    case "$_rw" in
        blessing|clan_help_gold|cave_gold_boost)
            resource_log "$_rr" "$_ra" "$_rw" negado
            unset _rr _ra _rw _rs; return 1 ;;

        cave_mission_silver)
            if [ "$_rr" != "silver" ]; then
                resource_log "$_rr" "$_ra" "$_rw" negado
                unset _rr _ra _rw _rs; return 1
            fi
            resource_log "$_rr" "$_ra" "$_rw" permitido
            unset _rr _ra _rw _rs; return 0 ;;

        career_gold_mission)
            # Secao 8: no maximo 100 de ouro, e so se o saldo ANTES do gasto
            # for maior que 2000. Fora disso a carreira roda sem ouro.
            if [ "$_rr" != "gold" ] || [ "$_ra" -gt 100 ] || [ "$_rs" -le 2000 ]; then
                resource_log "$_rr" "$_ra" "$_rw" negado
                unset _rr _ra _rw _rs; return 1
            fi
            resource_log "$_rr" "$_ra" "$_rw" permitido
            unset _rr _ra _rw _rs; return 0 ;;

        clan_treasury_gold)
            # Secao 15: 10 de ouro por dia, uma vez.
            if [ "$_rr" != "gold" ] || [ "$_ra" -gt 10 ]; then
                resource_log "$_rr" "$_ra" "$_rw" negado
                unset _rr _ra _rw _rs; return 1
            fi
            resource_log "$_rr" "$_ra" "$_rw" permitido
            unset _rr _ra _rw _rs; return 0 ;;

        clan_treasury_silver|statue_bonus)
            resource_log "$_rr" "$_ra" "$_rw" permitido
            unset _rr _ra _rw _rs; return 0 ;;

        *)
            resource_log "$_rr" "$_ra" "$_rw" negado
            unset _rr _ra _rw _rs; return 1 ;;
    esac
}

# Marcacao "uma vez por dia" / "dia alternado", usada pela tesouraria.
resource_dia_feito() { [ "`cat "$TMP/$1" 2>/dev/null`" = "`date +%Y%m%d`" ]; }
resource_dia_marcar() { date +%Y%m%d > "$TMP/$1" 2>/dev/null; }
