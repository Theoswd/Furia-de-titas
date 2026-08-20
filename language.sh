#!/bin/sh

# Cache de traducoes.
#
# CORRECAO 1: o caminho era "$HOME/twm/translations.po". Esse diretorio nao
# existe no layout multi-contas, entao o touch falhava em silencio, o cache
# NUNCA persistia e cada mensagem de interface disparava um POST bloqueante
# para translate.disroot.org — por conta, para sempre.
#
# CORRECAO 2 (multi-contas): a chave do cache era apenas o texto, SEM o
# idioma. Duas contas em idiomas diferentes liam e escreviam as mesmas
# entradas, uma sobrescrevendo a traducao da outra. Agora a chave e
# "idioma|texto" e o arquivo fica no diretorio da conta.
TRANSLATIONS_FILE="${TMP:-$HOME/.twm}/translations.po"
SOURCE="en"

# Escapa o texto para poder entrar num literal JSON com seguranca.
json_escape() {
    printf '%s' "$1" | sed 's/\/\\/g; s/"/\\"/g; s/	/\t/g'
}

get_translation() {
    target="$1"
    text="$2"

    # Sem jq nao ha como ler a resposta; devolve o original em vez de travar.
    command -v jq > /dev/null 2>&1 || { printf '%s' "$text"; return 0; }

    url="https://translate.disroot.org/translate"
    esc=`json_escape "$text"`
    data="{\"q\":\"${esc}\",\"source\":\"${SOURCE}\",\"target\":\"${target}\",\"format\":\"text\",\"alternatives\":0,\"api_key\":\"\"}"

    # CORRECAO: sem --max-time o worker travava indefinidamente quando o
    # servico de traducao ficava lento.
    curl -s --connect-timeout 5 --max-time 10 \
         -X POST "$url" -H "Content-Type: application/json" -d "$data" \
        | jq -r '.translatedText // empty'
}

load_translations() {
    _dir=`dirname "$TRANSLATIONS_FILE"`
    [ -d "$_dir" ] || mkdir -p "$_dir" 2>/dev/null
    [ -f "$TRANSLATIONS_FILE" ] || : > "$TRANSLATIONS_FILE" 2>/dev/null
    unset _dir
}

# Uso: translate_and_cache "$LANGUAGE" "texto"
translate_and_cache() {
    target_lang="$1"
    text="$2"

    text=`echo "$text" | xargs 2>/dev/null || echo "$text"`

    is_func=""
    case "$text" in
        __FUNC__*)
            is_func="yes"
            text=`echo "$text" | sed 's/^__FUNC__ //'`
            ;;
    esac

    # Idioma ingles (ou vazio): devolve sem traduzir e sem trafego de rede.
    if [ "$target_lang" = "en" ] || [ -z "$target_lang" ]; then
        echo "$text"
        return 0
    fi

    prefix=""
    rest="$text"
    if [ "$is_func" = "yes" ]; then
        prefix=`echo "$text" | sed -n 's/^\([^[:space:]]*-\) .*/\1 /p'`
        if [ -n "$prefix" ]; then
            rest=`echo "$text" | sed "s/^${prefix}//"`
        fi
    fi

    # Recarrega o caminho: $TMP so existe depois que o twm.sh define a conta.
    TRANSLATIONS_FILE="${TMP:-$HOME/.twm}/translations.po"
    load_translations

    # Busca no cache com chave "idioma|texto|traducao" (-F = literal, evita
    # que caracteres do texto sejam interpretados como regex).
    translated_text=`grep -F "${target_lang}|${text}|" "$TRANSLATIONS_FILE" 2>/dev/null | tail -n 1 | cut -d'|' -f3-`

    if [ -n "$translated_text" ]; then
        echo "$translated_text"
        return 0
    fi

    if [ -n "$prefix" ]; then
        raw=`get_translation "$target_lang" "$rest"`
        translated_text="${prefix}${raw}"
    else
        translated_text=`get_translation "$target_lang" "$text"`
    fi

    if [ -z "$translated_text" ]; then
        echo "$text"
        return 0
    fi

    printf '%s|%s|%s\n' "$target_lang" "$text" "$translated_text" >> "$TRANSLATIONS_FILE" 2>/dev/null

    echo "$translated_text"
}
