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

- conta no Titans War com **level 16+** e **50 pontos de treinamento** para algumas batalhas;
- conexão de internet estável;
- um dos ambientes abaixo:

| Ambiente | Observação |
|---|---|
| **Termux** (Android) | recomendado — instale **[pela F-Droid](https://f-droid.org/packages/com.termux/)**; a versão da Play Store está desatualizada e **não funciona** com pacotes atuais |
| **VPS Linux / Ubuntu / Debian / WSL** | testado e verificado — veja **[Rodando em outros sistemas](#rodando-em-outros-sistemas)** |
| **iSH** (iPhone/iPad) | funciona, mas o iOS suspende o app em segundo plano — leia as ressalvas na mesma seção |

O guia principal abaixo usa o **Termux**. Para os demais ambientes, os passos equivalentes estão em [Rodando em outros sistemas](#rodando-em-outros-sistemas).

---

## Instalação no Termux — passo a passo

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
## Rodando em outros sistemas

O bot é escrito em shell POSIX puro e não depende do Termux para funcionar — as únicas chamadas específicas do Termux (`termux-wake-lock`) são silenciadas quando não existem. Abaixo, o estado de cada plataforma.

| Plataforma | Estado | Roda em segundo plano |
|---|---|---|
| **Termux** (Android) | recomendado | sim, com `termux-wake-lock` |
| **VPS Linux** | **recomendado para uso 24/7** — com serviço systemd | sim, sempre |
| **Ubuntu / Debian / WSL** | **testado — 8/8** | sim |
| **iSH** (iPhone/iPad) | funciona com ressalvas sérias | **não de forma confiável** |

---

### Ubuntu, Debian e WSL

Testado em **Ubuntu 26.04 LTS sobre WSL2**, com `/bin/sh` apontando para **dash** (o shell POSIX mais estrito). Todos os 33 scripts passam, os módulos carregam, a pausa do laço principal funciona, os 4 servidores respondem e o encerramento por grupo de processos funciona.

**1. Instale as dependências**

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

**2. Vá para a sua pasta pessoal**

> **Importante — no WSL, não instale em pasta do Windows.** O terminal costuma abrir em `/mnt/c/...` (o disco do Windows visto de dentro do Linux). Dois problemas surgem daí:
>
> - **erro na instalação:** pastas do sistema como `/mnt/c/Windows/System32` são somente leitura, e o `git clone` falha com `could not create work tree dir: Permission denied`;
> - **suas credenciais ficam desprotegidas:** o WSL **não aplica permissões POSIX** em `/mnt/c`. Um `chmod 600` no `accounts.conf` é silenciosamente ignorado e o arquivo permanece `777` — legível e gravável por qualquer um. Testado e confirmado.
>
> A pasta pessoal do Linux (`~`, ou seja `/home/seu-usuario`) fica no sistema de arquivos ext4 real, onde as permissões funcionam. É lá que o bot deve ficar.

```bash
cd ~
```

**3. Baixe e prepare**

```bash
git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo && chmod +x play.sh setup.sh stop.sh worker.sh twm.sh
```

**4. Verifique a integridade**

```bash
sha256sum -c .integrity --quiet && echo "Scripts íntegros"
```

Confirme também que as permissões estão sendo aplicadas de verdade:

```bash
touch .permcheck && chmod 600 .permcheck && ls -l .permcheck && rm .permcheck
```

Deve mostrar `-rw-------`. Se mostrar `-rwxrwxrwx`, você está numa pasta do Windows — volte ao passo 2.

**5. Cadastre e rode**

```bash
./setup.sh
```

```bash
./play.sh
```

> **Atenção no WSL:** a distribuição é encerrada pouco depois que o último processo termina. Os workers são lançados desanexados e mantêm a distribuição viva, mas fechar todos os terminais é um risco desnecessário. O jeito robusto é usar `tmux`:
>
> ```bash
> sudo apt install -y tmux && tmux new -s twm
> ```
>
> Rode `./play.sh` dentro da sessão e desconecte com **Ctrl+B** seguido de **D**. Para voltar: `tmux attach -t twm`.

Em servidor Linux comum (VPS), o mesmo procedimento vale e é ainda mais estável — sem gerenciamento de bateria interferindo.

---

### VPS Linux — a melhor opção

Um servidor Linux é o ambiente ideal: fica de pé 24 horas, não depende do seu aparelho estar ligado, não sofre com gerenciamento de bateria, e permite instalar o bot como **serviço do systemd** — que inicia sozinho no boot e reinicia se o processo cair.

**Consumo de recursos.** Cada conta ocupa dois processos de shell, com cerca de **2 MB** de memória residente cada, mais um `curl` transitório. Entre os ciclos as contas ficam dormindo, então o uso de CPU é próximo de zero. Um VPS modesto de **1 núcleo e 1 GB** já roda dezenas de contas com folga; o gargalo real nunca é o servidor, e sim quantas contas o jogo tolera vindas de um mesmo IP.

**1. Conecte-se e crie um usuário comum**

Provedores costumam entregar acesso como `root`. **Não rode o bot como root** — se algo der errado, o estrago é no sistema inteiro. Crie um usuário normal:

```bash
adduser twm && usermod -aG sudo twm && su - twm
```

**2. Instale as dependências**

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

**3. Baixe na pasta pessoal**

```bash
cd ~ && git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo && chmod +x play.sh setup.sh stop.sh worker.sh twm.sh install-service.sh
```

**4. Verifique a integridade**

```bash
sha256sum -c .integrity --quiet && echo "Scripts íntegros"
```

**5. Cadastre as contas**

```bash
./setup.sh
```

**6. Instale como serviço**

O script detecta seu usuário e o caminho, gera a unidade do systemd e a instala. Ele se recusa a rodar como root e avisa se o diretório estiver num disco montado onde as permissões não valem.

```bash
./install-service.sh
```

**7. Inicie**

```bash
sudo systemctl start twm
```

A partir daqui o bot sobe sozinho a cada reinício do servidor.

**Comandos do dia a dia:**

| O quê | Comando |
|---|---|
| Ver estado | `systemctl status twm` |
| Log ao vivo | `journalctl -u twm -f` |
| Log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |
| Parar | `sudo systemctl stop twm` |
| Reiniciar | `sudo systemctl restart twm` |
| Não iniciar no boot | `sudo systemctl disable twm` |

> Quando não há terminal, o painel de contas fica oculto — ele seria reimpresso a cada 20 segundos no journal. A supervisão continua ativa: workers que caem são relançados e isso é registrado no log da conta.

**Cuidados com o servidor.** Um VPS exposto à internet é alvo de varredura constante. O mínimo razoável:

```bash
sudo apt install -y ufw && sudo ufw allow OpenSSH && sudo ufw --force enable
```

E autenticação por chave SSH em vez de senha — rode isto **na sua máquina**, não no servidor:

```bash
ssh-copy-id twm@SEU_IP
```

Depois de confirmar que a chave funciona, desative o login por senha em `/etc/ssh/sshd_config` (`PasswordAuthentication no`) e recarregue com `sudo systemctl reload ssh`.

---
### iSH (iPhone / iPad)

O **[iSH](https://ish.app/)** é um emulador x86 que roda **Alpine Linux** no iOS. O código é compatível, mas **o iOS é o problema**, não o bot.

**Instalação:**

```bash
apk update && apk add git curl jq tzdata bash
```

```bash
git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo && chmod +x play.sh setup.sh stop.sh worker.sh twm.sh
```

```bash
./setup.sh
```

```bash
./play.sh
```

**Antes de tentar, entenda as três limitações — nenhuma tem solução dentro do bot:**

1. **O iOS suspende aplicativos em segundo plano.** Esta é a limitação decisiva. O iSH tenta contornar mantendo uma sessão de áudio silenciosa, mas o sistema encerra o app de qualquer forma depois de um tempo variável. Na prática, o bot **para quando você sai do app ou bloqueia a tela**, e não há como garantir o contrário. Um bot que existe para rodar sozinho perde boa parte do sentido nessa condição.

2. **Emulação x86 é lenta.** O iSH interpreta instruções x86 em cima do ARM do iPhone. Cada requisição envolve iniciar um processo `curl` novo, e o bot faz dezenas por ciclo. Espere lentidão perceptível e consumo alto de bateria.

3. **BusyBox no lugar do GNU.** O Alpine usa BusyBox, cuja implementação de vários comandos é reduzida. O código foi ajustado para isso — a codificação em base64, por exemplo, deixou de usar a opção `-w 0`, que **não existe** no BusyBox e faria o cadastro de contas falhar. Se encontrar outra incompatibilidade, [abra uma issue](https://github.com/Theoswd/TitasWar-Sung-Jinwoo/issues) com a mensagem de erro.

> **Transparência:** não tenho um dispositivo iOS para testar. A compatibilidade acima vem de auditoria do código contra o comportamento conhecido do BusyBox, não de execução real. As instruções do Ubuntu/WSL, essas sim, foram executadas e verificadas. Se você testar no iSH, relate o resultado numa issue — bom ou ruim.

**Alternativa melhor para quem só tem iPhone:** rode em uma VPS Linux barata (há opções por poucos dólares ao mês) e acesse por SSH pelo celular com o [Termius](https://termius.com/) ou similar. O bot fica de pé 24 h por dia, sem depender do seu aparelho estar ligado, com tela acesa ou com bateria.

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
<summary><b>Uma conta não loga mesmo com a senha certa</b></summary>

Use o diagnóstico. Ele usa a credencial já salva, mostra exatamente o que o servidor responde e **nunca exibe a senha**:

```bash
./diagnose.sh
```

Isso lista as contas numeradas. Depois rode com o número da conta:

```bash
./diagnose.sh 4
```

O resultado separa as causas:

| Conclusão | Significa | O que fazer |
|---|---|---|
| **O SERVIDOR RECUSOU a credencial** | o servidor respondeu com erro de autenticação | senha errada, conta banida, ou o nome cadastrado não é o nome de login. Teste a mesma senha no navegador |
| **LOGIN FUNCIONOU** | a sessão foi criada, mas o bot achou que não | falha na detecção — abra uma issue com a saída |
| **Formulário sem mensagem de erro** | sessão descartada | indício de bloqueio de IP; teste no navegador pela mesma rede |

O diagnóstico também mostra o IP de saída da máquina, útil para comparar com o IP em que você costuma jogar.
</details>

<details>
<summary><b>"could not create work tree dir: Permission denied" ao clonar</b></summary>

Você está tentando instalar numa pasta do Windows (o terminal do WSL costuma abrir em `/mnt/c/Windows/System32`, que é somente leitura).

Vá para a sua pasta pessoal do Linux e repita:

```bash
cd ~ && git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo && chmod +x play.sh setup.sh stop.sh worker.sh twm.sh
```

Isto não é só sobre o erro: em `/mnt/c` o WSL **não aplica permissões POSIX**, então o `chmod 600` do `accounts.conf` seria ignorado e suas credenciais ficariam com acesso liberado. Instale sempre em `~`.

Para conferir onde você está:

```bash
pwd
```

Deve começar com `/home/`, não com `/mnt/`.
</details>

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
├── diagnose.sh      Diagnostica falha de login de uma conta
├── install-service.sh  Instala como servico do systemd (VPS/Linux)
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
