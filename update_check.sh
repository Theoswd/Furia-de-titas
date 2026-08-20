# update_check.sh - Atualizacao MANUAL e verificavel
#
# A versao anterior desta funcao era o problema de seguranca mais grave do
# projeto (SEC-01):
#
#   - baixava de https://raw.githubusercontent.com/hugoviegas/TitansWarPro/,
#     um repositorio de TERCEIRO, diferente do que o usuario clonou;
#   - sobrescrevia play.sh, twm.sh, info.sh e outros — ou seja, trocava os
#     arquivos do modelo multi-contas pelos do modelo de conta unica;
#   - nao verificava assinatura nem checksum;
#   - usava "curl" sem --fail: um 404 tem corpo e sai com status 0, entao o
#     texto de erro virava o novo conteudo do script (truncando o arquivo);
#   - comparava versoes por "wc -c" (tamanho em bytes), que nao e integridade;
#   - era disparada automaticamente as 23:30 (run.sh), com N contas rodando
#     o mesmo update no mesmo diretorio ao mesmo tempo;
#   - terminava com "sed -i" em massa sobre TODOS os .sh — inclusive os que
#     estavam sendo interpretados naquele instante. O shell le scripts por
#     offset de byte: alterar um arquivo em execucao faz o interpretador
#     retomar no meio de um token.
#
# Agora a atualizacao e via git (integridade por SHA-1 de conteudo), exige
# arvore limpa, so faz fast-forward e nunca roda sozinha.

update() {
    if [ ! -t 0 ]; then
        printf "Atualizacao automatica desativada por seguranca.\n"
        printf "Para atualizar: pare o bot (./stop.sh), rode 'git pull' e revise o diff.\n"
        return 1
    fi

    if [ -z "$TWMDIR" ] || [ ! -d "$TWMDIR" ]; then
        printf "TWMDIR nao definido.\n"
        return 1
    fi

    if ! command -v git > /dev/null 2>&1; then
        printf "git nao instalado. Rode: pkg install git\n"
        return 1
    fi

    if [ ! -d "$TWMDIR/.git" ]; then
        printf "Este diretorio nao e um repositorio git.\n"
        printf "Atualize manualmente clonando a versao nova.\n"
        return 1
    fi

    printf "AVISO: atualizar substitui os scripts. Pare o bot antes (./stop.sh).\n"
    printf "Continuar? (y/n): "
    read -r _u
    case "$_u" in y|Y) ;; *) printf "Cancelado.\n"; return 1 ;; esac

    ( cd "$TWMDIR" || exit 1

      if [ -n "$(git status --porcelain)" ]; then
          printf "Ha alteracoes locais nao commitadas. Update abortado para nao perde-las.\n"
          printf "Revise com: git status\n"
          exit 1
      fi

      printf "Buscando atualizacoes...\n"
      git fetch --quiet origin || { printf "Falha ao buscar.\n"; exit 1; }

      _branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      [ -z "$_branch" ] && _branch="master"

      printf "Alteracoes pendentes:\n"
      git --no-pager log --oneline "HEAD..origin/${_branch}" 2>/dev/null | head -20

      # --ff-only: recusa merge inesperado. O git ja garante integridade do
      # conteudo por hash, ao contrario da comparacao por tamanho anterior.
      if git merge --ff-only "origin/${_branch}" 2>/dev/null; then
          printf "Atualizado. Reinicie com ./play.sh\n"
      else
          printf "Nao foi possivel atualizar por fast-forward. Resolva manualmente.\n"
          exit 1
      fi
    )
}
