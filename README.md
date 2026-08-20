# TWM — Titans War Macro

Bot multi-contas para **[Titans War BR](https://furiadetitas.net)**, rodando em segundo plano no Termux, WSL, Linux ou VPS. Cada conta roda isolada em seu próprio processo, com cookie, configuração e log próprios.

**Autoria: Stephenn Curry** · Licença CC0 1.0 (domínio público)

---

## Antes de instalar

**Automação viola os termos de uso do jogo e pode resultar em banimento das suas contas.** Não existe configuração que elimine esse risco. Você assume essa decisão.

- use uma **senha exclusiva** para as contas do jogo;
- não compartilhe backups da pasta do bot nem de `~/.twm`;
- comece com poucas contas e observe alguns dias antes de escalar.

---

## O que o bot faz

### Ordem de prioridade dos eventos

Quando um evento está no horário, ele vem antes de qualquer rotina comum:

1. **Torneio dos Clãs**
2. **Altares dos Deuses**
3. **Vale dos Imortais**
4. **Rei dos Imortais**
5. **Coliseu do Clã**

### Fora dos horários de evento

| Atividade | Quando |
|---|---|
| **Missões do Clã** | prioridade máxima — verificadas antes de qualquer atividade |
| **Arena** | a cada 30 minutos |
| **Caverna** | sempre que disponível |
| **Carreira** | sempre que disponível |
| **Campanha** | sempre que disponível |
| **Cabana do Sábio** | missões, coleções e relíquias |
| **Liga dos Favoritos** | conforme configuração |
| **Masmorra do Clã** | a cada 8 h — o bot calcula o próximo horário após cada ataque |
| **Troca prata → ouro** | conforme configuração |
| **Coliseu** | todas as contas, das **00:30 às 04:30** |

### Regras de combinação

O bot **verifica as missões do clã antes** de iniciar Caverna, Carreira, Arena, Liga, elixir e coleta de pedras/evas. Se houver missão que aquela atividade completa, ele executa as duas em conjunto em vez de gastar a atividade à toa.

Também **apoia missões de outros membros** que estejam perto de concluir. O gasto de ouro em ajuda é limitado a **uma vez** por ciclo.

### Regras de ouro

- Missão parada com **mais de 1200 de ouro** disponível: o bot força a conclusão usando ouro.
- Ajuda a missão de companheiro: pode consumir ouro **uma única vez**.

### Batalhas

Sempre usa **elixir** e **bênção** antes de entrar.

### Liderança de clã

Se a conta for **líder**, o bot mantém a **estátua do clã** ativa com bônus de ouro e bônus de prata.

### Descanso

Entre ciclos, as contas ficam na **página inicial** — não em páginas de combate ou de evento.

---
## Requisitos

- conta no Titans War BR com **level 16+** e 50 pontos de treinamento para algumas batalhas;
- conexão estável;
- um destes ambientes:

| Ambiente | Observação |
|---|---|
| **Termux** (Android) | instale **[pela F-Droid](https://f-droid.org/packages/com.termux/)** — a versão da Play Store não funciona |
| **VPS Linux** | melhor opção para uso 24/7, com serviço systemd |
| **Ubuntu / Debian / WSL** | testado e verificado |

---

## Instalação

### Termux

```bash
pkg update && pkg upgrade -y
```

```bash
pkg install git curl wget jq util-linux -y
```

```bash
termux-wake-lock
```

> Vá também em **Configurações do Android → Bateria → Termux** e marque **"Sem restrições"**. Sem isso o Android encerra o bot com a tela desligada.

```bash
cd ~ && git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo
```

```bash
sha256sum -c .integrity --quiet && echo "Scripts íntegros"
```

### Ubuntu, Debian, WSL ou VPS

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

```bash
cd ~ && git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git && cd TitasWar-Sung-Jinwoo
```

> **No WSL, instale sempre em `~`, nunca em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões POSIX: o `chmod 600` do `accounts.conf` é ignorado e suas credenciais ficam com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

```bash
sha256sum -c .integrity --quiet && echo "Scripts íntegros"
```

---

## Uso

**Cadastrar contas** — pede usuário e senha (a senha não aparece na tela) e testa o login antes de salvar:

```bash
./setup.sh
```

**Iniciar:**

```bash
./play.sh
```

**Modos:**

| Comando | Efeito |
|---|---|
| `./play.sh` | rotina completa, seguindo a agenda |
| `./play.sh -cv` | foco exclusivo na caverna |
| `./play.sh -cl` | prioriza o coliseu |

**Parar tudo:**

```bash
./stop.sh
```

**Log de uma conta:**

```bash
tail -f ~/.twm/BR_NomeConta/twm.log
```

---

## O painel

```
--------------------------------------------------------------------
  TWM Multi-contas · BR                                     18:38:12
--------------------------------------------------------------------
 1 [on] Grimlock           HP 65312   EN 2125   LV 90   OU 402   PR 408,1M
 2 [on] Aro Borne          HP 37328   EN 2110   LV 87   OU 674   PR 673M
 3 [on] Abyssal Draco      HP 602     EN 1410   LV 40   OU 51    PR 20M
--------------------------------------------------------------------
  ATIVIDADE EM CONJUNTO
    Grimlock           -> Arena
    Aro Borne          -> Caverna
    Abyssal Draco      -> Missões
--------------------------------------------------------------------
  [on] 3 online   [ER] 0 parada(s)     Próximo: Torneio dos Clãs  18:55 BRT  (em 17m)
--------------------------------------------------------------------
```

Verde = online, amarelo = conectando, vermelho = erro. O rodapé mostra o próximo evento agendado, sempre em horário de Brasília.

Emoji no lugar do ASCII (exige fonte com emoji no terminal):

```bash
TWM_EMOJI=1 ./play.sh
```

---

## Rodar como serviço (VPS/Linux)

Inicia sozinho no boot e reinicia se cair:

```bash
./install-service.sh && sudo systemctl start twm
```

| O quê | Comando |
|---|---|
| Estado | `systemctl status twm` |
| Log ao vivo | `journalctl -u twm -f` |
| Parar | `sudo systemctl stop twm` |

---
## Diagnóstico

Quando uma conta não loga, este comando mostra exatamente o que o servidor responde (a senha nunca é exibida):

```bash
./diagnose.sh
```

```bash
./diagnose.sh 2
```

| Conclusão | Significa |
|---|---|
| **LOGIN FUNCIONOU** | sessão ativa; se o bot discorda, é falha de detecção |
| **O SERVIDOR RECUSOU** | senha errada, conta suspensa, ou o nome não é o de login |
| **Formulário sem erro** | sessão descartada — indício de bloqueio de IP |

---

## Segurança

**Onde ficam as credenciais.** Em `accounts.conf`, na pasta do bot, codificadas em base64.

> **Base64 não é criptografia** — é reversível por qualquer um com acesso ao arquivo. A proteção real vem das permissões: `600` no arquivo, `700` em `~/.twm`.

**Para onde a senha vai.** Apenas para `furiadetitas.net`. O código restringe o destino a um único domínio, sem caso genérico — não existe entrada de dados que faça a senha ir para outro lugar. Nenhum terceiro recebe nada.

**Atualização automática desativada.** Atualizar é manual e revisável:

```bash
./stop.sh && git pull && sha256sum -c .integrity --quiet && ./play.sh
```

**Verificar integridade a qualquer momento:**

```bash
sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```

O `.gitignore` impede que `accounts.conf`, cookies e logs sejam enviados caso você publique um fork. Nunca remova essas linhas.

---

## Solução de problemas

<details>
<summary><b>A conta fica presa em "login..."</b></summary>

```bash
./diagnose.sh 1
```

O intervalo entre tentativas dobra a cada falha (30s → 60s → … → 15 min). Se persistir, a senha provavelmente mudou: recadastre pelo `./setup.sh`.
</details>

<details>
<summary><b>O bot para quando a tela desliga (Android)</b></summary>

```bash
termux-wake-lock
```

E em **Configurações → Bateria → Termux**, marque **"Sem restrições"**.
</details>

<details>
<summary><b>Emoji aparecem como quadrados</b></summary>

A fonte do terminal não os suporta. Use o modo padrão (ASCII colorido), sem a variável `TWM_EMOJI`.
</details>

<details>
<summary><b>"could not create work tree dir: Permission denied"</b></summary>

Você está numa pasta do Windows. Vá para a pasta do Linux:

```bash
cd ~ && git clone https://github.com/Theoswd/TitasWar-Sung-Jinwoo.git
```
</details>

<details>
<summary><b>Recomeçar do zero mantendo as contas</b></summary>

```bash
./stop.sh && rm -rf ~/.twm && ./play.sh
```
</details>

---

## Desinstalar

Remove processos, serviço, dados das contas e o próprio diretório. Pede confirmação digitando `REMOVER`:

```bash
./uninstall.sh
```

> Apaga o `accounts.conf`. As contas **no jogo** não são afetadas, apenas o cadastro local.

---

## Estrutura

```
play.sh            Orquestrador: sobe um worker por conta e monitora
worker.sh          Supervisiona uma conta, reinicia o twm.sh se cair
twm.sh             Login e loop principal de uma conta
setup.sh           Cadastro de contas
stop.sh            Encerra workers e monitor
diagnose.sh        Diagnóstico de login
install-service.sh Instala como serviço do systemd
uninstall.sh       Remove tudo do sistema

run.sh             Agenda: o que executar em cada horário
crono.sh           Pausa entre ciclos e rotina start()
info.sh            Requisições HTTP, leitura de status, timeouts
function.sh        Configuração por conta
session_check.sh   Detecção de sessão
loginlogoff.sh     Reconexão quando a sessão expira

arena.sh  cave.sh  career.sh  campaign.sh  coliseum.sh  king.sh
clanid.sh  clanfight.sh  clandmg.sh  clancoliseum.sh  altars.sh
flagfight.sh  undying.sh  league.sh  trade.sh  allies.sh
check.sh  specialevent.sh  language.sh
```

Os dados de execução ficam fora do repositório, em `~/.twm/BR_<conta>/` — um diretório por conta.

---

<div align="center">

**Stephenn Curry**

Licença CC0 1.0 — domínio público

</div>
