#!/bin/sh
# diagnose.sh - Diagnostico de login de uma conta
#
# Usa a credencial ja salva no accounts.conf e reporta EXATAMENTE o que o
# servidor responde, para distinguir entre:
#   - senha incorreta ou conta banida  (o servidor recusa)
#   - bloqueio de IP                   (o servidor nao responde como esperado)
#   - login OK mas o bot nao detecta   (falha na deteccao de sessao)
#
# A SENHA NUNCA E EXIBIDA.
#
# Uso:  ./diagnose.sh        lista as contas
#       ./diagnose.sh 3      diagnostica a conta numero 3

_dir=$(dirname "$0")
TWMDIR=$(cd "$_dir" && pwd)
export TWMDIR
ACCOUNTS_FILE="$TWMDIR/accounts.conf"

G='\033[32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[01;36m'; N='\033[00m'

server_url() {
    case "$1" in
        1) echo "furiadetitas.net";; 2) echo "titanen.mobi";;
        3) echo "guerradetitanes.net";; 4) echo "tiwar.fr";;
        5) echo "in.tiwar.net";; 6) echo "tiwar-id.net";;
        7) echo "guerradititani.net";; 8) echo "tiwar.pl";;
        9) echo "tiwar.ro";; 10) echo "tiwar.ru";;
        11) echo "rs.tiwar.net";; 12) echo "cn.tiwar.net";;
        13) echo "tiwar.net";;
    esac
}
server_tag() {
    case "$1" in
        1) echo BR;; 2) echo DE;; 3) echo ES;; 4) echo FR;; 5) echo IN;;
        6) echo ID;; 7) echo IT;; 8) echo PL;; 9) echo RO;; 10) echo RU;;
        11) echo SR;; 12) echo ZH;; 13) echo EN;;
    esac
}
server_scheme() { case "$1" in 5) echo http;; *) echo https;; esac; }

[ -s "$ACCOUNTS_FILE" ] || { printf "${R}Nenhuma conta cadastrada.${N}\n"; exit 1; }

if [ -z "$1" ]; then
    printf "${C}Contas cadastradas:${N}\n\n"
    n=1
    grep -E '^[0-9]+\|' "$ACCOUNTS_FILE" | while IFS='|' read -r s u _e; do
        printf "  %d) [%s] %s\n" "$n" "$(server_tag "$s")" "$u"
        n=$((n+1))
    done
    printf "\nUse: ${Y}./diagnose.sh N${N}   (N = numero da conta)\n"
    exit 0
fi

case "$1" in *[!0-9]*|'') printf "${R}Numero invalido.${N}\n"; exit 1 ;; esac

line=$(grep -E '^[0-9]+\|' "$ACCOUNTS_FILE" | sed -n "${1}p")
[ -n "$line" ] || { printf "${R}Conta %s nao existe.${N}\n" "$1"; exit 1; }

srv=$(printf '%s' "$line" | cut -d'|' -f1)
user=$(printf '%s' "$line" | cut -d'|' -f2)
enc=$(printf '%s' "$line" | cut -d'|' -f3)
tag=$(server_tag "$srv"); host=$(server_url "$srv"); sch=$(server_scheme "$srv")
URL="${sch}://${host}"

printf "${C}=== Diagnostico: [%s] %s ===${N}\n" "$tag" "$user"
printf "  servidor: %s\n\n" "$URL"

CK=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/diag_$$.txt")
UA="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"
rm -f "$CK"

# ---- 1. conectividade
printf "1) Conectividade... "
code=$(curl -s -o /dev/null -w '%{http_code}' -A "$UA" --max-time 25 "$URL/" 2>/dev/null)
if [ "$code" = "200" ]; then printf "${G}OK (HTTP 200)${N}\n"
else printf "${R}FALHOU (HTTP %s)${N}\n" "$code"
     printf "   O servidor nao respondeu. Pode ser queda, DNS ou bloqueio de rede.\n"
     rm -f "$CK"; exit 1; fi

# ---- 2. cookie de sessao
printf "2) Cookie de sessao... "
curl -s -o /dev/null -A "$UA" -c "$CK" --max-time 25 "$URL/" 2>/dev/null
if grep -q PHPSESSID "$CK" 2>/dev/null; then printf "${G}recebido${N}\n"
else printf "${R}NAO recebido${N}\n"; printf "   O servidor nao criou sessao. Indicio de bloqueio de IP.\n"; fi

# ---- 3. caracteres do usuario
printf "3) Nome de usuario... "
if printf '%s' "$user" | LC_ALL=C grep -q '[^ -~]'; then
    printf "${Y}contem caracteres nao-ASCII${N} (cirilico/acentos)\n"
    printf "   Isso pode afetar a codificacao. Anote como possivel causa.\n"
else printf "${G}so ASCII${N}\n"; fi

# ---- 4. login real
printf "4) Enviando login (senha nao e exibida)... "
creds=$(printf '%s' "$enc" | base64 -d 2>/dev/null)
lu=$(printf '%s' "$creds" | sed 's/login=//;s/&pass=.*//')
lp=$(printf '%s' "$creds" | sed 's/.*&pass=//')
unset creds
[ -n "$lp" ] || { printf "${R}credencial ilegivel${N}\n"; rm -f "$CK"; exit 1; }
printf "(usuario decodificado: %s, senha: %s caracteres)\n" "$lu" "$(printf '%s' "$lp" | wc -c | tr -d ' ')"

RESP="${TMPDIR:-/tmp}/diag_resp_$$.html"
curl -s -L -A "$UA" -c "$CK" -b "$CK" \
     --data-urlencode "login=${lu}" --data-urlencode "pass=${lp}" \
     --max-time 30 "$URL/?sign_in=1" -o "$RESP" 2>/dev/null
unset lu lp

# ---- 5. o que o servidor respondeu
printf "5) Resposta do servidor:\n"
sz=$(wc -c < "$RESP" 2>/dev/null)
printf "   tamanho: %s bytes\n" "$sz"

AUTHERR=0
grep -qiE "неверн|Ошибка авториз|incorretamente|Falha na autoriz|incorrect|invalid" "$RESP" 2>/dev/null && AUTHERR=1
FORM=0
grep -qE "name='pass'" "$RESP" 2>/dev/null && FORM=1

# ---- 6. pagina do usuario
PAGE="${TMPDIR:-/tmp}/diag_user_$$.html"
curl -s -L -A "$UA" -c "$CK" -b "$CK" --max-time 30 "$URL/user" -o "$PAGE" 2>/dev/null
LOGGED=0
grep -qiE "class='white'|\[level|/logout" "$PAGE" 2>/dev/null && LOGGED=1

printf "\n${C}=== CONCLUSAO ===${N}\n"
if [ "$AUTHERR" = 1 ]; then
    printf "${R}O SERVIDOR RECUSOU a credencial.${N}\n"
    printf "  Mensagem encontrada na resposta:\n"
    grep -oiE "(неверн|Ошибка авториз|incorretamente|Falha na autoriz)[^<]{0,60}" "$RESP" | head -2 | sed 's/^/    > /'
    printf "\n  Causas, em ordem de probabilidade:\n"
    printf "    1. Senha alterada ou digitada errada no cadastro\n"
    printf "    2. Conta banida ou suspensa\n"
    printf "    3. O nome de usuario nao e exatamente o de login\n"
    printf "\n  Teste a MESMA senha no navegador em %s\n" "$URL"
elif [ "$LOGGED" = 1 ]; then
    printf "${G}LOGIN FUNCIONOU.${N}\n"
    printf "  A pagina /user mostra sinais de sessao ativa.\n"
    printf "  Se o bot mesmo assim diz que falhou, o problema esta na\n"
    printf "  DETECCAO de sessao, nao no login. Reporte com esta saida.\n"
elif [ "$FORM" = 1 ]; then
    printf "${Y}Ainda aparece o formulario de login, mas SEM mensagem de erro.${N}\n"
    printf "  Isso normalmente indica bloqueio de IP ou sessao descartada.\n"
    printf "  Teste o mesmo login pelo navegador NESTA mesma rede.\n"
else
    printf "${Y}Resposta inesperada.${N}\n"
    printf "  Guarde os arquivos abaixo e reporte:\n"
    printf "    %s\n    %s\n" "$RESP" "$PAGE"
    RESP=""; PAGE=""
fi

printf "\n  IP de saida desta maquina: %s\n" "$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo 'nao detectado')"
[ -n "$RESP" ] && rm -f "$RESP"
[ -n "$PAGE" ] && rm -f "$PAGE"
rm -f "$CK"
