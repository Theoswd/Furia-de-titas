#!/bin/sh
# setup.sh - Gerenciamento de contas do TWM Multi-contas

# CORRECAO (seguranca): sem umask o accounts.conf nascia 644 (legivel por
# qualquer processo do mesmo UID no Termux).
umask 077

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
unset _dir

ACCOUNTS_FILE="$TWMDIR/accounts.conf"

# Carrega funcoes de verificacao de sessao
. "$TWMDIR/session_check.sh"

GREEN='\033[32m'
GOLD='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[01;36m'
RESET='\033[00m'

# ============================================================
#  SOMENTE SERVIDOR BR (furiadetitas.net)
#  O suporte aos outros 12 servidores foi removido a pedido.
#  O campo de servidor continua no accounts.conf (sempre "1")
#  para nao quebrar cadastros existentes.
# ============================================================
server_url()    { case "$1" in 1) echo "furiadetitas.net" ;; esac; }
server_tag()    { case "$1" in 1) echo "BR" ;; esac; }
server_scheme() { echo "https"; }

show_menu() {
    clear
    printf "${CYAN}╔══════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║     TWM Multi-contas — Setup         ║${RESET}\n"
    printf "${CYAN}╚══════════════════════════════════════╝${RESET}\n\n"
    n=0
    [ -f "$ACCOUNTS_FILE" ] && n=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    printf "Contas cadastradas: ${GOLD}%s${RESET}\n\n" "$n"
    printf "${GOLD}1)${RESET} Listar contas\n"
    printf "${GOLD}2)${RESET} Adicionar conta\n"
    printf "${GOLD}3)${RESET} Remover conta\n"
    printf "${GOLD}4)${RESET} Testar login\n"
    printf "${GOLD}0)${RESET} Sair\n\n"
    printf "Opcao: "
}

list_accounts() {
    clear
    printf "${CYAN}=== Contas cadastradas ===${RESET}\n\n"
    if [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ]; then
        printf "${RED}Nenhuma conta cadastrada ainda.${RESET}\n"
    else
        n=1
        while IFS='|' read -r srv user _enc; do
            case "$srv" in ''|\#*) continue ;; esac
            [ -z "$user" ] && continue
            url=$(server_url "$srv")
            tag=$(server_tag "$srv")
            printf "${GOLD}%d)${RESET} [%s] %-20s %s\n" "$n" "$tag" "$user" "$url"
            n=$((n + 1))
        done < "$ACCOUNTS_FILE"
    fi
    printf "\nENTER para voltar..."
    read -r _d
}

# Servidor unico: nao ha o que escolher.
show_servers() {
    printf "
${CYAN}Servidor: BR - furiadetitas.net${RESET}
"
}

add_account() {
    clear
    printf "${CYAN}=== Adicionar conta ===${RESET}\n"
    show_servers
    srv=1

    url=$(server_url "$srv")
    tag=$(server_tag "$srv")

    printf "Usuario (%s): " "$url"
    read -r user
    user=$(printf %s "$user" | tr -d '[:cntrl:]')

    # CORRECAO: nao havia validacao. Um "|" no nome corrompe o formato
    # do accounts.conf e uma "/" quebra o caminho do diretorio da conta.
    case "$user" in
        *"|"*) printf "${RED}Nome nao pode conter | ${RESET}\n"; sleep 2; return ;;
        */*)   printf "${RED}Nome nao pode conter / ${RESET}\n"; sleep 2; return ;;
    esac
    [ -z "$user" ] && printf "${RED}Usuario vazio.${RESET}\n" && sleep 2 && return

    # Verifica duplicata
    if [ -f "$ACCOUNTS_FILE" ] && grep -q "^${srv}|${user}|" "$ACCOUNTS_FILE" 2>/dev/null; then
        printf "${RED}Conta [%s] %s ja existe.${RESET}\n" "$tag" "$user"
        sleep 2; return
    fi

    printf "Senha: "
    stty -echo 2>/dev/null
    read -r pass
    stty echo 2>/dev/null
    printf "\n"
    [ -z "$pass" ] && printf "${RED}Senha vazia.${RESET}\n" && sleep 2 && return

    printf "Testando login em %s...\n" "$url"

    # O servidor IN so atende em HTTP (porta 443 recusa conexao).
    if [ "$(server_scheme "$srv")" = "http" ]; then
        printf "${RED}AVISO: este servidor nao suporta HTTPS.${RESET}
"
        printf "A senha trafegara em texto claro. Continuar? (y/n): "
        read -r _ok
        case "$_ok" in y|Y) ;; *) printf "Cancelado.
"; sleep 2; return ;; esac
    fi

    if test_login "$(server_scheme "$srv")://$url" "$user" "$pass"; then
        encoded=$(printf "login=%s&pass=%s" "$user" "$pass" | base64 | tr -d '[:space:]')
        printf "%s|%s|%s\n" "$srv" "$user" "$encoded" >> "$ACCOUNTS_FILE"
        chmod 600 "$ACCOUNTS_FILE" 2>/dev/null
        printf "${GREEN}[OK] Conta [%s] %s adicionada!${RESET}\n" "$tag" "$user"
    else
        printf "${RED}Login nao confirmado automaticamente.${RESET}\n"
        printf "Isso pode ocorrer por bloqueio de IP no teste.\n"
        printf "Salvar mesmo assim? (y/n): "
        read -r force
        case "$force" in
            y|Y)
                encoded=$(printf "login=%s&pass=%s" "$user" "$pass" | base64 | tr -d '[:space:]')
                printf "%s|%s|%s\n" "$srv" "$user" "$encoded" >> "$ACCOUNTS_FILE"
                chmod 600 "$ACCOUNTS_FILE" 2>/dev/null
                printf "${GOLD}Conta salva sem validacao.${RESET}\n"
                ;;
            *) printf "Conta nao salva.\n" ;;
        esac
    fi

    unset pass encoded
    sleep 2
}

remove_account() {
    clear
    printf "${CYAN}=== Remover conta ===${RESET}\n\n"
    [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ] && \
        printf "${RED}Nenhuma conta.${RESET}\n" && sleep 2 && return

    n=1
    while IFS='|' read -r srv user _enc; do
        case "$srv" in ''|\#*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        printf "${GOLD}%d)${RESET} [%s] %s\n" "$n" "$tag" "$user"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    printf "\nNumero (0 = cancelar): "
    read -r choice
    [ "$choice" = "0" ] || [ -z "$choice" ] && return

    total=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$total" in ''|*[!0-9]*) total=0 ;; esac
    case "$choice" in
        *[!0-9]*) printf "${RED}Invalido.${RESET}\n"; sleep 2; return ;;
    esac
    [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && \
        printf "${RED}Invalido.${RESET}\n" && sleep 2 && return

    # Extrai a linha escolhida (apenas linhas validas)
    line=$(grep '|' "$ACCOUNTS_FILE" | sed -n "${choice}p")
    srv=$(echo "$line" | cut -d'|' -f1)
    user=$(echo "$line" | cut -d'|' -f2)
    tag=$(server_tag "$srv")

    printf "Remover [%s] %s? (y/n): " "$tag" "$user"
    read -r confirm
    case "$confirm" in
        y|Y)
            # CORRECAO: "grep -v" trata o nome como REGEX. Um nome com
            # metacaractere (., *, [) removeria a conta errada. O awk abaixo
            # compara os campos 1 e 2 como texto literal.
            awk -F'|' -v s="$srv" -v u="$user" '!($1==s && $2==u)' \
                "$ACCOUNTS_FILE" > "$ACCOUNTS_FILE.tmp" && \
                mv "$ACCOUNTS_FILE.tmp" "$ACCOUNTS_FILE"
            printf "${GREEN}Removida.${RESET}\n"
            acc_dir="$HOME/.twm/${tag}_${user}"
            if [ -d "$acc_dir" ]; then
                printf "Remover dados em %s? (y/n): " "$acc_dir"
                read -r rd
                case "$rd" in y|Y) rm -rf "$acc_dir" && printf "Dados removidos.\n" ;; esac
            fi
            ;;
        *) printf "Cancelado.\n" ;;
    esac
    sleep 2
}

test_account() {
    clear
    printf "${CYAN}=== Testar login ===${RESET}\n\n"
    [ ! -f "$ACCOUNTS_FILE" ] || [ ! -s "$ACCOUNTS_FILE" ] && \
        printf "${RED}Nenhuma conta.${RESET}\n" && sleep 2 && return

    n=1
    while IFS='|' read -r srv user _enc; do
        case "$srv" in ''|\#*) continue ;; esac
        [ -z "$user" ] && continue
        tag=$(server_tag "$srv")
        printf "${GOLD}%d)${RESET} [%s] %s\n" "$n" "$tag" "$user"
        n=$((n + 1))
    done < "$ACCOUNTS_FILE"

    printf "\nNumero: "
    read -r choice
    total=$(grep -c -E '^[0-9]+[|]' "$ACCOUNTS_FILE" 2>/dev/null)
    case "$total" in ''|*[!0-9]*) total=0 ;; esac
    case "$choice" in *[!0-9]*) printf "${RED}Invalido.${RESET}\n"; sleep 2; return ;; esac
    [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] && \
        printf "${RED}Invalido.${RESET}\n" && sleep 2 && return

    line=$(grep '|' "$ACCOUNTS_FILE" | sed -n "${choice}p")
    srv=$(echo "$line" | cut -d'|' -f1)
    user=$(echo "$line" | cut -d'|' -f2)
    encoded=$(echo "$line" | cut -d'|' -f3)
    tag=$(server_tag "$srv")
    url=$(server_url "$srv")

    creds=$(echo "$encoded" | base64 -d 2>/dev/null)
    luser=$(echo "$creds" | sed 's/login=//;s/&pass=.*//')
    lpass=$(echo "$creds" | sed 's/.*&pass=//')
    unset creds

    printf "Testando [%s] %s...\n" "$tag" "$user"

    if test_login "$(server_scheme "$srv")://$url" "$luser" "$lpass"; then
        printf "${GREEN}[OK] Login confirmado.${RESET}\n"
    else
        printf "${RED}[FALHOU] Login nao confirmado.${RESET}\n"
        printf "Nota: pode ser bloqueio de IP. O bot pode funcionar mesmo assim.\n"
    fi
    unset lpass
    sleep 3
}

# Loop principal
while true; do
    show_menu
    read -r opt
    case "$opt" in
        1) list_accounts ;;
        2) add_account ;;
        3) remove_account ;;
        4) test_account ;;
        0) printf "\nSaindo...\n"; exit 0 ;;
    esac
done
