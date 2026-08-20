# Correções aplicadas

Documento técnico de tudo que foi alterado, com o arquivo, a causa e o efeito prático. Serve para auditoria: qualquer pessoa pode conferir cada item no código.

**23 arquivos modificados · 33/33 passam em `sh -n` · nenhuma função removida**

Revisão por **Stephenn Curry**. Base: [ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo](https://github.com/ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo).

---

## 1. Multi-contas

### 1.1 Laço principal a 100% de CPU · `crono.sh`

A pausa entre ciclos era feita com `read -r -t "$i" cmd`, esperando um comando do usuário por `$i` segundos. Mas o `play.sh` lança os workers com `< /dev/null`: o `read` encontra EOF e retorna **imediatamente**. A pausa nunca acontecia, e o laço `while true; do twm_start; done` do `twm.sh` girava sem parar.

Consequências: CPU saturada **por conta**, `twm.log` crescendo até encher o armazenamento, e a rotina `start()` sendo reexecutada centenas de vezes dentro do mesmo minuto — uma rajada de requisições idênticas ao servidor.

**Correção:** sem terminal (`[ ! -t 0 ]`), dorme de verdade com `sleep`. Com terminal, mantém o modo interativo original.

**Medido:** `func_cat` retornava em `0s`; agora respeita o intervalo pedido.

### 1.2 Sessão expirada nunca detectada · `crono.sh`, `loginlogoff.sh`

`login_logoff()` estava definida em `loginlogoff.sh` mas **nenhum arquivo a chamava**. O login acontecia só no boot. Quando o cookie expirava, a conta seguia requisitando páginas de login indefinidamente, enquanto o painel continuava exibindo `online` — porque só verificava se o processo existia (`kill -0`), não se a sessão estava viva.

**Correção:** `start()` chama `login_logoff` no início de cada ciclo e pula o ciclo se a sessão não puder ser restabelecida.

### 1.3 Configuração nunca recebia os valores padrão · `info.sh`, `function.sh`

`language_setup()` era executada **no momento do `source`** de `info.sh`. Como o `twm.sh` define `$TMP` antes, ela criava `config.cfg` contendo apenas `LANGUAGE=en`. Em seguida `load_config()` via que o arquivo "já existia" e nunca gravava os padrões — **todas as `FUNC_*` ficavam vazias em todas as contas**.

Efeitos: `use_elixir` e `check_rewards` comparavam com `"n"`; vazio ≠ `"n"`, então **executavam mesmo desligados** (queimando elixir); `league.sh` fazia `[ "$N" -gt "" ]`, gerando erro de operando a cada ciclo.

**Correção:** a chamada automática foi removida; `load_config()` agora completa as chaves ausentes **sempre**, o que também **repara** configurações já gravadas de forma incompleta. A ordem em `twm.sh` passou a ser `load_config` → `language_setup`.

**Medido:** `config.cfg` nascia com 1 chave; agora nasce com 15, e um arquivo quebrado é restaurado para 15 sem perder escolhas do usuário.

### 1.4 Modo de execução compartilhado entre contas · `run.sh`, `cave.sh`, `twm.sh`

Havia três caminhos diferentes para o mesmo arquivo:

| Ação | Caminho | Problema |
|---|---|---|
| gravava | `$HOME/twm/runmode_file` | diretório inexistente no layout multi-contas — falha silenciosa |
| lia | `$TWMDIR/runmode_file` | outro arquivo |
| gravava | `$TWMDIR/runmode_file` (cave.sh) | **um arquivo para todas as contas** |

Além disso o `twm.sh` **ignorava o `$1`** que o `worker.sh` passava. Resultado: `./play.sh -cv` e `-cl` não tinham efeito, e uma conta saindo do modo caverna trocava o modo de todas.

**Correção:** `runmode_file` passou a ser por conta (`$TMP/`). O `twm.sh` respeita o argumento; o `play.sh` apaga o arquivo ao lançar, para que a opção de linha de comando prevaleça num início limpo.

### 1.5 Modo caverna travava em laço infinito · `cave.sh`

`cave_start()` chama `set_cave_limits()`, que faz `read -r input_gold` dentro de `while true`. Sem terminal, a entrada vem vazia, cai no ramo `''|*[!0-9]*` e imprime "Invalid value" **para sempre**. O modo caverna nunca iniciava e o log enchia o disco.

**Correção:** sem TTY, usa os limites salvos na configuração da conta e segue. Removida também a reexecução aninhada (`"$TWMDIR/twm.sh" -boot` seguida de `exit 0`), que empilhava processos — basta sair, porque o `worker.sh` reinicia o `twm.sh`.

### 1.6 Processos órfãos e sessões duplicadas · `play.sh`, `stop.sh`

Ao relançar, o `play.sh` fazia `kill -9` apenas no PID do worker. O `twm.sh` **filho continuava vivo**, órfão, com a sessão do jogo aberta. Rodar `./play.sh` duas vezes deixava duas sessões por conta disputando o mesmo `cookie.txt`.

Pior: `kill -0` verifica **existência**, não **identidade**. Com o PID reciclado pelo kernel, o `kill -9` acertava um processo inocente.

**Correção:** workers são lançados com `setsid` (líderes de grupo de processos) e encerrados por grupo. Antes de sinalizar, o `/proc/<pid>/cmdline` é conferido para garantir que o PID ainda é um worker.

### 1.7 Todas as contas autenticando no mesmo instante · `play.sh`, `twm.sh`

Os workers subiam em sequência imediata e o `twm.sh` enviava o **mesmo POST de login duas vezes** (bloco duplicado). Eram `2N` autenticações no mesmo segundo, do mesmo IP. O limite do servidor derrubava quase todas, e o backoff exponencial sem aleatoriedade as mantinha **sincronizadas**, reincidindo em bloco a cada 300s.

**Correção:** intervalo de 5–20s entre lançamentos; backoff com variação aleatória; e o login passou a ser um GET (estabelece o cookie) seguido de **um único** POST com a credencial.

### 1.8 Worker morto ficava morto · `play.sh`

O monitor detectava o processo caído e apenas exibia `ERRO`. A conta ficava parada indefinidamente.

**Correção:** o monitor relança o worker e registra no log da conta.

### 1.9 Cache de tradução compartilhado entre idiomas · `language.sh`

O arquivo apontava para `$HOME/twm/translations.po` — diretório inexistente, então o `touch` falhava em silêncio e **o cache nunca persistia**: cada mensagem de interface disparava um POST bloqueante para um serviço externo, por conta, indefinidamente.

Pior: a chave do cache era **apenas o texto, sem o idioma**. Contas em idiomas diferentes liam e sobrescreviam as entradas umas das outras.

**Correção:** cache por conta, chave `idioma|texto`, `--max-time` no curl, e texto escapado antes de entrar no JSON.

**Medido:** `pt` → "Coliseu" e `de` → "Kolosseum" convivem sem se corromper.

### 1.10 Log sem rotação · `worker.sh`

Nada limitava o crescimento do `twm.log`. Com o laço da seção 1.1, ele chegava a encher o armazenamento — e o Android passava a matar o processo, o que aparentava "bug aleatório".

**Correção:** rotação automática em 5 MB.

---
## 2. Segurança

### 2.1 Atualização automática substituía os scripts por código de terceiro · `update_check.sh`, `run.sh`

**Este era o problema mais grave do projeto.**

Todo dia às 23:30, `run.sh` chamava `update()`, que baixava arquivos de `raw.githubusercontent.com/hugoviegas/TitansWarPro/` — um repositório **diferente** do que o usuário clonou — e os gravava por cima dos locais. Somando os defeitos:

- **sem verificação de origem ou integridade:** nenhuma assinatura, nenhum checksum. Quem controlasse aquele repositório executava código no aparelho de todo mundo;
- **`curl` sem `--fail`:** um HTTP 404 ou 500 tem corpo e sai com status 0. O texto de erro virava o novo conteúdo do script, **truncando** o arquivo;
- **integridade por `wc -c`:** comparar tamanho em bytes detecta mudança, não integridade — colide trivialmente;
- **lista incompleta:** `worker.sh`, `setup.sh`, `stop.sh` e `session_check.sh` não estavam nela, então o resultado era metade multi-contas e metade conta única;
- **`easyinstall.sh` e `update.sh`** não existem localmente, então eram marcados como desatualizados **sempre**;
- **concorrência:** N contas rodavam o mesmo update no mesmo diretório ao mesmo tempo;
- **`sed -i` em massa ao final**, sobre todos os `.sh` — inclusive os que estavam sendo interpretados naquele instante. O shell lê scripts por *offset* de byte: alterar um arquivo em execução faz o interpretador retomar no meio de um token.

**Correção:** a chamada automática foi removida de `run.sh`. A função `update()` agora usa `git` (integridade por hash de conteúdo), exige árvore limpa, só aceita fast-forward, recusa rodar sem terminal e mostra o log das mudanças antes de aplicar. O `sed -i` em massa foi eliminado — normalização de fim de linha é papel do `.gitattributes`.

### 2.2 Credenciais visíveis na lista de processos · `play.sh`, `worker.sh`

A credencial em base64 era passada como `argv[3]` do `worker.sh`. O `argv` de um processo é legível em `/proc/<pid>/cmdline`, e o worker roda **indefinidamente** — a credencial ficava exposta o tempo todo. O `unset TWM_ENCODED` não ajudava: limpa a variável, não o `argv` do kernel.

Alcance real: no Android, outros **aplicativos** não enxergam os processos do Termux (isolamento por UID). O risco concreto é qualquer script rodando **dentro do próprio Termux**, backup por ADB, aparelho com root, ou um `ps` colado num print de suporte.

**Correção:** o `play.sh` grava a credencial em `cript_file` (modo `600`) e o `worker.sh` recebe apenas o caminho do diretório da conta. Variável de ambiente também não serviria — `/proc/<pid>/environ` tem o mesmo problema.

### 2.3 Permissões permissivas · `play.sh`, `setup.sh`, `worker.sh`, `twm.sh`

Sem `umask`, `~/.twm` e `accounts.conf` nasciam `755`/`644`.

**Correção:** `umask 077` no topo dos executáveis, `chmod 700` em `~/.twm` e nos diretórios de conta, `chmod 600` em `accounts.conf` e `cript_file`.

### 2.4 Arquivo de configuração era executado como código · `function.sh`

`load_config()` fazia `. "$CONFIG_FILE"`, ou seja, **executava** o `config.cfg` como shell script. Qualquer linha ali rodaria com os privilégios do worker.

Auditei todas as escritas: os quatro pontos que gravam configuração validam os valores (`y`/`n`, `1–999`, `1–4`), então **não era explorável no código atual**. Foi corrigido mesmo assim: no dia em que alguém gravasse ali um nome de clã ou apelido vindo do servidor, viraria execução remota de código.

**Correção:** parser explícito com allowlist de chaves e validação de caracteres. Configuração é dado, nunca código.

**Testado:** um comando injetado no `config.cfg` não é executado e a chave desconhecida é descartada.

### 2.5 Interpretador de comandos embutido · `crono.sh`

```sh
case "$cmd" in
    *) $cmd ;;    # qualquer string vinda do stdin virava comando
esac
```

Sem aspas e em posição de comando. Não era alcançável porque o stdin é `/dev/null`, mas bastaria alguém rodar `./twm.sh` num terminal para virar um shell dentro do bot.

**Correção:** allowlist explícita de comandos.

### 2.6 Sinal enviado a PID derivado de regex truncada · `info.sh`

```sh
TEFPID=`echo "$!" | grep -o -E '([0-9]{2,6})'`
```

A regex captura no máximo 6 dígitos, mas o `pid_max` do Linux vai até 4194304 (7 dígitos). Num kernel com `pid_max` alto, o PID `1234567` virava `123456` e o `kill` acertava **outro processo** do usuário.

**Correção:** usa `$!` diretamente, sem regex e sem o subshell que envolvia a função. O `sleep` antes da verificação foi **mantido de propósito** — ele impõe ~1s de espaçamento entre requisições, um limitador de taxa natural que eu não quis remover.

**Testado:** processo rápido retorna assim que termina; processo lento é encerrado no timeout, sem vazar; o piso de 1s continua valendo.

### 2.7 `kill` sem validar identidade · `play.sh`, `stop.sh`

`kill -0` confirma que um PID **existe**, não que ele é seu. Com PID reciclado, o `kill -9` atingia um processo inocente.

**Correção:** confere `/proc/<pid>/cmdline` antes de sinalizar, e sinaliza o grupo de processos.

### 2.8 `curl` sem restrição de protocolo nem timeout · `info.sh`, `session_check.sh`

Não havia `-k` nem `--insecure` em lugar nenhum — a validação de certificado sempre esteve ativa. As lacunas eram outras:

| Faltava | Consequência |
|---|---|
| `--proto` / `--proto-redir` | um redirecionamento poderia levar o POST de login para HTTP, expondo a senha em texto claro |
| `--max-time` / `--connect-timeout` | `do_login` e `login_logoff` são síncronos: um socket pendurado travava o worker para sempre, e o painel continuava mostrando a conta como viva |
| `-sS` em vez de `-s` | erros de rede eram engolidos — daí o "parou e não sei por quê" |

**Correção:** todas aplicadas, com o protocolo ajustado por servidor (o servidor IN só atende em HTTP).

**Testado:** forçar `http://` num servidor cujo esquema é `https` retorna erro; os quatro servidores testados respondem normalmente.

### 2.9 Envio de dados a serviço externo de tradução · `language.sh`

O texto da interface era interpolado direto num literal JSON, sem escape, e enviado a um serviço de terceiro sem timeout. Os textos são literais do código (não há dado do usuário), então não era explorável — mas o padrão estava errado e o tráfego era contínuo por falta de cache.

**Correção:** escape do JSON, `--max-time`, cache funcional, e nenhuma requisição quando o idioma é o original.

---
## 3. Correções funcionais

### 3.1 URLs de combate quebradas · 6 arquivos, 21 linhas

`ATK` e `KINGATK` extraíam a URL com `| sed -n 1p`, mas `DODGE`, `HEAL`, `STONE`, `ATKRND`, `UNRIP` e `SHIELD` **não**. Quando a página trazia mais de um link correspondente, o arquivo ficava com várias linhas e o consumo — `run_curl "${URL}$(cat DODGE)"` — montava uma URL com quebra de linha embutida. O `curl` falhava e **a ação de combate era perdida em silêncio**: o personagem ficava parado apanhando.

**Correção:** `| sed -n 1p` uniforme em `king.sh`, `altars.sh`, `flagfight.sh`, `clanfight.sh`, `clandmg.sh` e `clancoliseum.sh`.

### 3.2 `exit` dentro de função encerrava o worker · 9 arquivos, 15 ocorrências

`cd "$TMP" || exit` aparecia dentro de funções carregadas por `source`. Nesse contexto, `exit` não sai da função — **encerra o processo inteiro**.

**Correção:** `|| return 1` em todas as ocorrências, confirmadas uma a uma como estando dentro de função.

### 3.3 Teste de login falhava sempre no Termux · `session_check.sh`

O arquivo de cookie era gravado em `/tmp/twm_test_$$.txt`. **O Termux não tem `/tmp`** — usa `$PREFIX/tmp`, exposto em `$TMPDIR`. O `curl` não conseguia gravar, a sessão se perdia entre as duas chamadas e o cadastro exibia "Login nao confirmado" para **toda** conta.

**Correção:** `${TMPDIR:-/tmp}`.

### 3.4 Detecção de sessão frágil · `session_check.sh`

`is_logged_in()` devolvia "não logado" se a substring `sign_in` aparecesse em **qualquer** lugar da página — inclusive num link de rodapé — e "logado" se aparecesse a palavra `exit`, genérica demais.

**Correção:** o sinal negativo passou a ser a presença do **formulário** de login (campo de senha ou *action* de `sign_in`), que só existe na página deslogada.

**Testado:** as páginas deslogadas de `tiwar.net`, `furiadetitas.net` e `tiwar.ru` são classificadas corretamente.

### 3.5 `read -n` não existe no shell usado · `function.sh`, `allies.sh`, `cave.sh`, `update_check.sh`

`read -r -n 1` é específico do Bash. O `play.sh` executa tudo via `$TOYBOX`, e `toybox sh`/`dash` não suportam a opção — o `read` falhava de imediato e os menus entravam em laço.

**Correção:** `read -r` simples.

### 3.6 Divisão por valor vazio · `info.sh`, `cave.sh`

Quando uma requisição era cortada pelo timeout, `FIXHP`/`FIXMP` ficavam vazios e o `awk` dividia por zero, produzindo `nan`/`inf` nas comparações de cura e ataque. `check_cave_limits` comparava `[ "$CAVE_GOLD_LIMIT" -gt 0 ]` sem garantir valor.

**Correção:** validação antes de calcular, com fallback explícito. (`king.sh` já fazia isso em `king_percent()` — o padrão dele foi replicado.)

### 3.7 Contagem de contas incorreta · `play.sh`, `setup.sh`

```sh
total=$(grep -c '|' "$ACCOUNTS_FILE" 2>/dev/null || echo 0)
```

Quando o `grep -c` não acha nada, ele imprime `0` **e** sai com status 1 — então o `|| echo 0` acrescentava um segundo `0` e a variável virava `"0\n0"`. Além disso, contava linhas comentadas.

**Correção:** `grep -c -E '^[0-9]+\|'` sem o `||`, com validação numérica.

### 3.8 Nome de conta sem validação · `setup.sh`, `play.sh`

Um `|` no nome corrompe o formato do `accounts.conf`; uma `/` quebra o caminho do diretório da conta. E `grep -v "^${srv}|${user}|"` trata o nome como **expressão regular** — um nome com `.`, `*` ou `[` removeria a conta errada.

**Correção:** validação na entrada, remoção de CR e caracteres de controle, e remoção de conta via `awk` com comparação literal de campos.

### 3.9 `restart_script` perigoso e inoperante · `run.sh`

```sh
pgrep -f "sh.*twm/twm.sh"   # não casava com o diretório real
nohup sh "$HOME/twm/twm.sh" # caminho inexistente
kill -9 "$pidf"             # vários PIDs entre aspas = argumento inválido
```

Não matava nada — mas quem instalasse numa pasta chamada `twm` mataria **todas as contas** de uma vez.

**Correção:** encerra apenas o processo atual; o `worker.sh` daquela conta o reinicia em ~15s, sem tocar nas demais.

### 3.10 Limpeza de estado incompleta · `twm.sh`

`func_unset()` não limpava `CLD`, `FULL`, `RHP`, `HLHP`, `ACCESS`, `SHIELD`, `UNRIP` nem `KINGATK` — valores velhos vazavam para o ciclo seguinte e contaminavam decisões de cura e ataque.

**Correção:** lista completada.

### 3.11 Requisições redundantes · `loginlogoff.sh`

`run_curl` já injeta `-c`/`-b`; as chamadas repetiam as mesmas opções.

**Correção:** removidas.

---

## 4. Servidores

Os 13 domínios foram resolvidos e testados individualmente pelo `<title>` da página.

| Servidor | Situação encontrada | Ação |
|---|---|---|
| **IT** — `guerraditiani.net` | **NXDOMAIN** — não resolve mais | corrigido para **`guerradititani.net`**, confirmado servindo *"Guerra di Titani online"* |
| **IN** — `in.tiwar.net` | resolve, mas a **porta 443 recusa conexão**. O código forçava `https://` para todos, então esse servidor **nunca funcionou** | adicionada `server_scheme()`; usa HTTP com aviso explícito de senha em texto claro |
| **RU** — `tiwar.ru` | **funcionando** (`Битва титанов`, `/?sign_in=1` responde 200) | nenhuma |
| Demais 10 | funcionando | nenhuma |

---

## 5. Deixado para outro momento

Itens de alto impacto, que exigem reestruturação e teste dedicado:

1. **Separar código de estado.** Hoje `$TWMDIR` é os dois — foi isso que permitiu ao atualizador se autodestruir.
2. **Reuso de conexão TLS.** Cada requisição é um processo novo, logo um *handshake* completo (~240 ms de overhead em 4G). Exige repensar o modelo `( ... ) & time_exit`.
3. **Parsers de HTML resilientes.** Dezenas de `grep`/`sed` sobre HTML, que quebram a cada mudança de layout do jogo.
4. **Assinatura GPG nas atualizações.** O `git` garante integridade por hash, mas não autenticidade do autor.
5. **`--fail` no curl.** Exige revisar cada chamador, porque vários dependem do corpo em respostas não-2xx.
6. **Login sem `-L`.** Fecharia o resíduo de redirecionamento 307; mantido para não arriscar quebrar a autenticação.

---

## 6. Verificação

Tudo abaixo foi executado e conferido, não apenas revisado por leitura:

```
sintaxe            33/33 scripts passam em sh -n
bytes              nenhum NUL, nenhum CR
funções            nenhuma removida; 8 adicionadas
carregamento       26 módulos + 19 funções-chave presentes
laço principal     antes 0s (busy-loop) → depois pausa real
caverna            antes travava → depois retorna em 1s
configuração       antes 1 chave → depois 15, com reparo de config quebrado
config como código comando injetado não é executado
time_exit          rápido: retorna ao terminar · lento: encerrado no timeout · piso de 1s mantido
downgrade TLS      http em servidor https → bloqueado
rede               4 servidores testados ao vivo, todos respondendo
sessão             3 servidores classificados corretamente como deslogados
```

Para conferir a integridade dos scripts a qualquer momento:

```bash
sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```
