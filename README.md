# TWM — Titans War Macro · Multi-contas

Bot de automação das tarefas diárias de **[Titans War](https://tiwar.net)**, rodando em segundo plano no **Termux** (Android). Suporta **várias contas ao mesmo tempo**, cada uma isolada em seu próprio processo, diretório, cookie e configuração.

Esta é uma versão **revisada e corrigida** do projeto, focada em três coisas que estavam quebradas: o funcionamento real do multi-contas, o consumo de recursos do aparelho e a segurança das credenciais.

---

## Créditos

Este repositório é uma continuação do trabalho de:

- **[ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo](https://github.com/ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo)** — base deste projeto

Todo o mérito da criação original é de quem veio antes. O objetivo aqui é **apenas devolver algo à comunidade**: o bot tinha falhas que faziam o aparelho esquentar, o armazenamento encher e contas pararem de jogar sem aviso. As correções estão documentadas linha a linha em **[CORRECOES.md](CORRECOES.md)**, para que qualquer pessoa possa auditar, discordar ou melhorar.

Correções e revisão técnica por **Stephenn Curry**.

Licença **CC0 1.0 Universal** (domínio público) — use, modifique e redistribua livremente.

---

## Antes de instalar — leia

**Automação viola os termos de uso da maioria dos jogos online, incluindo este.** Usar o bot pode resultar em **banimento das suas contas**. Não existe configuração que elimine esse risco. Você assume essa decisão.

Recomendações práticas se decidir usar:

- use uma **senha exclusiva** para as contas do jogo, nunca a mesma do e-mail ou banco;
- não compartilhe backups da pasta do bot nem de `~/.twm`;
- comece com **uma conta** e observe alguns dias antes de escalar.

---

## O que o bot faz

| Recurso | Estado |
|---|---|
| **Arena** | joga até acabar a mana |
| **Carreira** | batalha e coleta recompensas quando disponível |
| **Coliseu** | batalhas das 00:00 às 04:00; modo exclusivo disponível |
| **Caverna** | todas as funções, incluindo loop contínuo |
| **Campanha** | funcional |
| **Masmorra do Clã** | entra sempre que disponível |
| **Rei dos Imortais** | participa, com modo sniper de finalização |
| **Eventos diários** | incluindo eventos temporários |
| **Troca ouro/prata** | sempre que disponível |
| **Cabana do Sábio** | missões, coleções e relíquias |

---

## O que foi corrigido nesta versão

Resumo do que mudou na prática. O detalhamento técnico está em **[CORRECOES.md](CORRECOES.md)**.

### Multi-contas — o que impedia de funcionar

| Sintoma que você via | Causa real |
|---|---|
| Aparelho esquentando, bateria acabando rápido | O laço principal **não pausava**: o bot lia o teclado para "dormir", mas rodando em segundo plano não há teclado, então girava a 100% de CPU — **por conta** |
| Armazenamento enchendo sozinho | Consequência do acima: o `twm.log` crescia sem limite |
| Conta aparece "online" mas parou de jogar | A função que reconectava sessão expirada **existia mas nunca era chamada** |
| Configurações não colavam | O arquivo de config nascia com **uma única linha**, e os valores padrão nunca eram gravados |
| `./play.sh -cv` e `-cl` sem efeito | O modo de execução era lido de um arquivo **compartilhado por todas as contas**, ignorando o que você digitou |
| Modo caverna nunca iniciava | Travava num laço infinito imprimindo "Invalid value" |
| Contas duplicadas após reiniciar | Ao relançar, só o processo pai era encerrado; o filho continuava vivo com a sessão aberta |
| Quase todas as contas caindo no login | Todas autenticavam no mesmo segundo, do mesmo IP, derrubadas pelo limite do servidor |
| Bot parado apanhando sem esquivar | URLs de ação de combate saíam quebradas quando a página tinha mais de um link |

### Segurança

- **Atualização automática desativada.** Ela baixava e sobrescrevia os scripts a partir de um repositório de terceiro, todo dia, sem verificar assinatura nem integridade — e sem `--fail`, de modo que uma resposta de erro podia **truncar** seus arquivos. Agora a atualização é manual e verificável.
- **Credenciais fora da linha de comando.** Antes ficavam visíveis em `ps` / `/proc` durante toda a execução.
- **Permissões restritas** (`600` no `accounts.conf`, `700` em `~/.twm`).
- **Config deixou de ser executado como código.**
- **HTTPS reforçado** — bloqueio de downgrade para HTTP em redirecionamentos, e timeouts para o bot não travar em socket pendurado.

### Servidores

- **IT** corrigido: `guerraditiani.net` (que não resolve mais) → **`guerradititani.net`**.
- **IN** (`in.tiwar.net`) passa a funcionar: esse servidor **não oferece HTTPS** (porta 443 recusa conexão) e o código forçava `https://` para todos. Agora usa HTTP, com aviso explícito de que a senha trafega em texto claro.
- **RU** (`tiwar.ru`), **BR**, **EN** e os demais foram verificados um a um e estão corretos.

---
## Requisitos

- **Android** com **[Termux](https://f-droid.org/packages/com.termux/)** instalado **pela F-Droid**
  (a versão da Play Store está desatualizada e **não funciona** com pacotes atuais);
- conta no Titans War com **level 16+** e **50 pontos de treinamento** para algumas batalhas;
- conexão de internet estável.

---

## Instalação — passo a passo

Cada bloco abaixo é um comando. Cole um de cada vez no Termux e pressione **ENTER**.

### 1. Atualize o Termux

Deixa os pacotes do sistema em dia. Responda `Y` para as confirmações; se aparecer um menu de opções, pressione **ENTER** para aceitar o padrão.

```bash
pkg update && pkg upgrade -y
```

### 2. Instale as dependências

- `git` — baixar e atualizar o bot
- `curl` — falar com o servidor do jogo
- `jq` — ler respostas em JSON
- `util-linux` — fornece o `setsid`, usado para encerrar os workers corretamente

```bash
pkg install git curl wget jq util-linux -y
```

### 3. Impeça o Android de matar o Termux

O Android suspende apps em segundo plano. Sem isto, o bot para sozinho depois de alguns minutos com a tela desligada.

```bash
termux-wake-lock
```

> Além do comando, vá em **Configurações do Android → Bateria → Termux** e marque **"Sem restrições"** / **"Não otimizar"**. O nome exato varia conforme o fabricante.

### 4. Baixe o bot

```bash
git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git
```

### 5. Entre na pasta

```bash
cd TitasWar-Sung-Jinwoo
```

### 6. Dê permissão de execução

```bash
chmod +x play.sh setup.sh stop.sh worker.sh twm.sh
```

### 7. Confira se está tudo íntegro

Compara os scripts com as somas de verificação publicadas. Deve responder sem nenhuma linha de erro.

```bash
sha256sum -c .integrity --quiet && echo "Scripts íntegros"
```

Se aparecer `Scripts íntegros`, a instalação está correta.

### 8. Cadastre suas contas

Abre um menu interativo. Escolha `2` para adicionar. Ele pergunta o servidor, o usuário e a senha (a senha **não aparece** na tela enquanto você digita), e testa o login antes de salvar.

```bash
./setup.sh
```

Servidores disponíveis:

| Nº | Tag | Domínio | Nº | Tag | Domínio |
|---|---|---|---|---|---|
| 1 | BR | furiadetitas.net | 8 | PL | tiwar.pl |
| 2 | DE | titanen.mobi | 9 | RO | tiwar.ro |
| 3 | ES | guerradetitanes.net | 10 | RU | tiwar.ru |
| 4 | FR | tiwar.fr | 11 | SR | rs.tiwar.net |
| 5 | IN | in.tiwar.net *(só HTTP)* | 12 | ZH | cn.tiwar.net |
| 6 | ID | tiwar-id.net | 13 | EN | tiwar.net |
| 7 | IT | guerradititani.net | | | |

Repita o passo para cada conta. Não há limite fixo — o limite prático é a memória e a bateria do aparelho.

### 9. Inicie

```bash
./play.sh
```

O bot sobe um processo por conta, com um intervalo de alguns segundos entre elas (isso é proposital: evita que todas autentiquem ao mesmo tempo e sejam bloqueadas pelo servidor). Ao final, aparece um painel com o estado de cada conta, atualizado a cada 20 segundos.

---

## Modos de execução

| Comando | O que faz |
|---|---|
| `./play.sh` | Modo padrão — executa todas as tarefas conforme o horário |
| `./play.sh -cv` | Modo caverna — foca exclusivamente na caverna |
| `./play.sh -cl` | Modo coliseu — prioriza o coliseu |

---
## Acompanhando as contas

O painel do `./play.sh` mostra o estado de cada conta:

| Estado | Significa |
|---|---|
| `online` | rodando normalmente |
| `iniciando` / `carregando` | subindo, aguarde |
| `login...` | tentando autenticar (o intervalo aumenta a cada falha, até 5 min) |
| `reiniciando` | ciclo encerrado, voltando em 15s |
| `ERRO` | processo caiu — **o painel o relança automaticamente** |
| `parado` | encerrado pelo `./stop.sh` |

Para ver o log detalhado de **uma** conta, use a tag do servidor e o nome, por exemplo `BR_MinhaConta`:

```bash
tail -f ~/.twm/BR_MinhaConta/twm.log
```

Para listar as pastas de conta existentes:

```bash
ls ~/.twm/
```

---

## Parando o bot

Encerra todos os workers de todas as contas.

```bash
./stop.sh
```

---

## Atualizando

**A atualização automática foi desativada de propósito.** A versão anterior baixava e sobrescrevia os scripts sozinha, todo dia às 23:30, a partir de um repositório de terceiro, sem verificar integridade. Isso significava que qualquer correção sua era desfeita — e que quem controlasse aquele repositório executava código no seu aparelho.

O processo correto é este, e leva 30 segundos:

```bash
cd ~/TitasWar-Sung-Jinwoo && ./stop.sh && git pull && sha256sum -c .integrity --quiet && ./play.sh
```

Se quiser revisar o que mudou **antes** de aplicar:

```bash
cd ~/TitasWar-Sung-Jinwoo && git fetch && git log --oneline HEAD..origin/main
```

---

## Segurança

**Onde ficam suas credenciais.** No arquivo `accounts.conf`, dentro da pasta do bot, codificadas em **base64**.

> **Base64 não é criptografia.** É uma codificação reversível: qualquer pessoa com acesso ao arquivo recupera a senha. A proteção real vem das permissões (`600` no arquivo, `700` em `~/.twm`), que restringem o acesso ao seu usuário.

**Para onde sua senha vai.** Apenas para o domínio oficial do servidor que você escolheu. O código restringe o destino a uma lista fixa de 13 domínios, sem caso genérico — não existe entrada de dados que faça a senha ir para outro lugar. Não há envio para nenhum terceiro.

**O `.gitignore` protege você.** Ele impede que `accounts.conf`, cookies e logs sejam enviados caso você faça um fork e publique. Nunca remova essas linhas.

**Verificação a qualquer momento:**

```bash
cd ~/TitasWar-Sung-Jinwoo && sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```

---

## Solução de problemas

<details>
<summary><b>"Login nao confirmado automaticamente" ao cadastrar</b></summary>

O teste de login não passou. Causas comuns, em ordem de probabilidade:

1. **Senha incorreta** — confira digitando de novo.
2. **Bloqueio de IP no teste** — comum em rede móvel/CGNAT. O `setup.sh` oferece salvar mesmo assim, e o bot costuma funcionar normalmente depois.
3. **Servidor fora do ar** — teste no navegador.

Para verificar uma conta já cadastrada, use a opção `4` do `./setup.sh`.
</details>

<details>
<summary><b>A conta fica presa em "login..."</b></summary>

Veja o log da conta:

```bash
tail -30 ~/.twm/BR_MinhaConta/twm.log
```

O intervalo entre tentativas dobra a cada falha (30s → 60s → 120s → 240s → 300s), com uma variação aleatória para não sincronizar todas as contas. Se persistir por mais de 15 minutos, a senha provavelmente mudou: remova e recadastre a conta pelo `./setup.sh`.
</details>

<details>
<summary><b>"worker nao iniciou"</b></summary>

Confira o log indicado na mensagem. Causas mais comuns: permissão de execução faltando (`chmod +x`) ou dependência ausente.

```bash
chmod +x play.sh setup.sh stop.sh worker.sh twm.sh && pkg install git curl jq util-linux -y
```
</details>

<details>
<summary><b>O bot para quando a tela desliga</b></summary>

É o gerenciamento de bateria do Android. Faça as duas coisas:

```bash
termux-wake-lock
```

E em **Configurações → Bateria → Termux**, marque **"Sem restrições"**.
</details>

<details>
<summary><b>Contas duplicadas / dois processos da mesma conta</b></summary>

Não deve mais acontecer (os workers agora são encerrados junto com seus filhos), mas se acontecer:

```bash
./stop.sh && pkill -f twm.sh && ./play.sh
```
</details>

<details>
<summary><b>Quero recomeçar do zero</b></summary>

Apaga todos os dados de execução, mas **mantém** as contas cadastradas:

```bash
./stop.sh && rm -rf ~/.twm && ./play.sh
```
</details>

---

## Desinstalar

Remove o bot e **todos** os dados, inclusive as contas cadastradas.

```bash
cd ~ && rm -rf TitasWar-Sung-Jinwoo ~/.twm
```

---

## Estrutura do projeto

```
TitasWar-Sung-Jinwoo/
├── play.sh          Orquestrador: sobe um worker por conta e monitora
├── worker.sh        Supervisiona uma conta (reinicia o twm.sh se cair)
├── twm.sh           Loop de jogo de uma conta (login + ciclo principal)
├── setup.sh         Menu de cadastro/remoção/teste de contas
├── stop.sh          Encerra todos os workers
│
├── run.sh           Agenda: o que executar em cada horário
├── crono.sh         Pausa entre ciclos e rotina start()
├── info.sh          Requisições HTTP, cores, timeouts
├── function.sh      Leitura e escrita de configuração
├── session_check.sh Detecção de sessão ativa
├── loginlogoff.sh   Reconexão quando a sessão expira
│
├── arena.sh  coliseum.sh  cave.sh  king.sh  campaign.sh  career.sh
├── clanfight.sh  clandmg.sh  clancoliseum.sh  clanid.sh  altars.sh
├── flagfight.sh  undying.sh  league.sh  trade.sh  allies.sh
├── check.sh  specialevent.sh  language.sh  crono.sh  ...
│
├── .integrity       Somas SHA-256 para verificar os scripts
├── .gitignore       Impede o envio de credenciais
├── CORRECOES.md     Detalhamento técnico das correções
└── README.md
```

Dados de execução ficam **fora** do repositório, em `~/.twm/<TAG>_<conta>/` — um diretório por conta, com cookie, configuração e log próprios.

---

## Contribuindo

Achou um bug ou tem uma correção? Abra uma **[issue](https://github.com/Theoswd/TitasWar-Sung-Jinwoo/issues)** ou mande um **pull request**. Descreva o sintoma, o servidor e cole o trecho relevante do log (**sem** o `accounts.conf`).

---

<div align="center">

**Correções e revisão técnica: Stephenn Curry**

Baseado em **[ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo](https://github.com/ramalhotimoteo1-oss/TitasWar-Sung-Jinwoo)**

Feito para a comunidade · Licença CC0 1.0 (domínio público)

</div>
