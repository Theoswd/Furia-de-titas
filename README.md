# Fúria de Titãs

Bot multi-contas para **[Fúria de Titãs](https://furiadetitas.net)**.

**Autoria: Stephenn Curry** · Licença CC0 1.0

---

## Aviso

Automação viola os termos de uso do jogo e pode resultar em **banimento das contas**. Você assume esse risco.

---

## Instalação — Termux (Android)

Instale o Termux **[pela F-Droid](https://f-droid.org/packages/com.termux/)**. A versão da Play Store não funciona.

**1.** Atualize os pacotes:

```bash
pkg update && pkg upgrade -y
```

**2.** Instale as dependências:

```bash
pkg install git curl wget jq util-linux -y
```

**3.** Impeça o Android de encerrar o bot:

```bash
termux-wake-lock
```

> Vá também em **Configurações → Bateria → Termux** e marque **"Sem restrições"**.

**4.** Baixe o bot:

```bash
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
```

**5.** Verifique a integridade:

```bash
cd ~/Furia-de-titas && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**6.** Cadastre as contas:

```bash
cd ~/Furia-de-titas && ./setup.sh
```

**7.** Inicie:

```bash
cd ~/Furia-de-titas && ./play.sh
```

---

## Instalação — WSL (Windows)

**1.** Instale as dependências:

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
```

**2.** Vá para a pasta pessoal do Linux:

```bash
cd ~
```

> **Nunca instale em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões, e o arquivo de credenciais fica com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

**3.** Baixe o bot:

```bash
git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
```

**4.** Verifique a integridade:

```bash
cd ~/Furia-de-titas && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**5.** Cadastre as contas:

```bash
cd ~/Furia-de-titas && ./setup.sh
```

**6.** Inicie:

```bash
cd ~/Furia-de-titas && ./play.sh
```

> Para o bot continuar rodando depois de fechar o terminal, use `tmux`:
>
> ```bash
> sudo apt install -y tmux && tmux new -s twm
> ```
>
> Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.
> **Se o `./play.sh` reclamar de diretório**, seu terminal está numa pasta que não existe mais. Rode `cd ~/Furia-de-titas` e tente de novo.

---

## Instalação — iSH (iPhone / iPad)

**1.** Instale as dependências:

```bash
apk update && apk add git curl jq tzdata bash
```

**2.** Baixe o bot:

```bash
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
```

**3.** Verifique a integridade:

```bash
cd ~/Furia-de-titas && sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**4.** Cadastre as contas:

```bash
cd ~/Furia-de-titas && ./setup.sh
```

**5.** Inicie:

```bash
cd ~/Furia-de-titas && ./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. A emulação também é lenta. Para uso contínuo, prefira Termux ou WSL.

---

## Comandos

> Todos os comandos incluem `cd ~/Furia-de-titas` porque precisam ser executados **dentro da pasta do bot**. Se você já estiver nela, o `cd` não atrapalha; se não estiver, ele evita o erro.

| O quê | Comando |
|---|---|
| Iniciar | `cd ~/Furia-de-titas && ./play.sh` |
| Pausar / retomar | `cd ~/Furia-de-titas && ./pause.sh` |
| Ver estado | `cd ~/Furia-de-titas && ./pause.sh status` |
| Parar tudo | `cd ~/Furia-de-titas && ./stop.sh` |
| Cadastrar contas | `cd ~/Furia-de-titas && ./setup.sh` |
| Diagnosticar login | `cd ~/Furia-de-titas && ./diagnose.sh` |
| Ver log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |

> **Pausar não desloga.** Os processos continuam vivos e a sessão no jogo permanece válida — ao retomar não há novo login. A pausa entra em vigor **ao fim do ciclo em andamento**, então uma conta no meio de uma batalha pode levar alguns minutos para parar. Para encerrar de vez, use `cd ~/Furia-de-titas && ./stop.sh`.

---

## Atualização

**A atualização automática está desativada de propósito.** A versão anterior baixava e sobrescrevia os scripts sozinha, todo dia, a partir de um repositório de terceiro, sem verificar assinatura nem integridade — isso é execução de código arbitrário no seu aparelho. Além disso, o download não checava falhas: uma resposta de erro do servidor podia **truncar seus arquivos**.

Atualize sempre manualmente:

```bash
cd ~/Furia-de-titas && ./stop.sh && git pull && sha256sum -c .integrity --quiet && ./play.sh
```

Para revisar o que mudou **antes** de aplicar:

```bash
cd ~/Furia-de-titas && git fetch && git log --oneline HEAD..origin/main
```

---

## Integridade

O arquivo `.integrity` guarda a soma SHA-256 de cada script. Serve para confirmar que nenhum arquivo foi alterado — por atualização malfeita, edição acidental ou modificação de terceiro.

Verifique a qualquer momento:

```bash
cd ~/Furia-de-titas && sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```

Se aparecer alguma linha de erro, um script está diferente do publicado. Nesse caso, restaure:

```bash
cd ~/Furia-de-titas && git checkout -- . && git pull
```

Se você mesmo editar algum script, gere um novo baseline:

```bash
cd ~/Furia-de-titas && sha256sum -b *.sh | sort -k2 > .integrity
```

---

## Solução de problemas

<details>
<summary><b>"Unable to read current working directory" ou o play.sh não inicia</b></summary>

Seu terminal está numa pasta que foi renomeada ou removida. Volte para a pasta do bot:

```bash
cd ~/Furia-de-titas
```

Depois rode o comando de novo.
</details>

<details>
<summary><b>A conta não loga / fica presa em "login..."</b></summary>

Rode o diagnóstico. Ele mostra o que o servidor responde e **nunca exibe a senha**:

```bash
cd ~/Furia-de-titas && ./diagnose.sh
```

Depois com o número da conta:

```bash
cd ~/Furia-de-titas && ./diagnose.sh 1
```

| Resultado | Significa |
|---|---|
| **LOGIN FUNCIONOU** | a sessão está ativa |
| **O SERVIDOR RECUSOU** | senha errada, conta suspensa, ou o nome não é o de login |
| **Formulário sem erro** | sessão descartada — indício de bloqueio de IP |

O intervalo entre tentativas dobra a cada falha, até 15 minutos.
</details>

<details>
<summary><b>"could not create work tree dir: Permission denied"</b></summary>

Você está numa pasta do Windows. Vá para a pasta do Linux:

```bash
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
```
</details>

<details>
<summary><b>"Your local changes would be overwritten by merge"</b></summary>

Descarte as alterações locais e atualize:

```bash
cd ~/Furia-de-titas && git checkout -- . && git pull
```
</details>

<details>
<summary><b>"[Process completed (signal 9)]" — o bot morre sozinho no meio do lançamento</b></summary>

`signal 9` é `SIGKILL`: **o Android matou o processo**, o bot não travou nem deu erro. Duas causas, nesta ordem:

**1. Limite de processos "fantasma" (Android 12 ou superior).** O sistema classifica como *phantom process* todo processo filho do Termux que ele não reconhece e, passando de **32 simultâneos**, mata sem avisar. Com o celular ligado no PC:

```bash
adb shell settings put global settings_enable_monitor_phantom_procs false
```

O ajuste volta ao normal quando o aparelho reinicia — é preciso repetir.

**2. Restrição de bateria.** Em **Configurações → Bateria → Termux**, marque **"Sem restrições"**, e mantenha o `termux-wake-lock` ativo.

> O consumo de processos por conta foi reduzido: cada página baixada gastava até 19 processos (um subshell, o `curl` e até 17 execuções de `sleep`), e agora gasta 3 fixos. Ainda assim, acima de 6 contas o ajuste do item 1 é recomendado.
</details>

<details>
<summary><b>O `./setup.sh` mostra "Contas cadastradas: 0" mas o `./play.sh` encontra as contas</b></summary>

Os dois estavam lendo **arquivos diferentes**. O `accounts.conf` fica dentro da pasta do bot e não é versionado, então quem clonou o repositório mais de uma vez acaba com duas cópias — uma com as contas e outra vazia.

O menu do `./setup.sh` e o cabeçalho do `./play.sh` agora **mostram sempre o caminho do arquivo em uso**. Compare os dois; se forem diferentes, apague a pasta que não tem as contas:

```bash
ls -la ~/Furia-de-titas/accounts.conf
```

Se o arquivo local não existir, os dois scripts procuram nos lugares conhecidos antes de desistir — não é mais possível um enxergar as contas e o outro não.
</details>

<details>
<summary><b>A coluna "ATIVIDADE EM CONJUNTO" fica sempre em "Página Principal"</b></summary>

Corrigido. O painel lê a página atual de um arquivo que só era escrito por `fetch_page` — mas todo o código de batalha (`king.sh`, `coliseum.sh`, `clanfight.sh`, `altars.sh`, `undying.sh`, entre outros, mais de 100 pontos) chama o `curl` por outro caminho e nunca atualizava esse arquivo. O registro passou para a função central de requisição, por onde toda chamada passa de verdade.

Entre um ciclo e outro a conta descansa na página inicial de propósito, então **"Página Principal" durante a espera é o estado correto** — o que mudou é que agora a batalha em andamento aparece.
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

A fonte do terminal não os suporta. Use o modo padrão, sem a variável `TWM_EMOJI`.
</details>

<details>
<summary><b>Contas duplicadas ou processos travados</b></summary>

```bash
cd ~/Furia-de-titas && ./stop.sh && pkill -f twm.sh && ./play.sh
```
</details>

<details>
<summary><b>Recomeçar do zero mantendo as contas cadastradas</b></summary>

```bash
cd ~/Furia-de-titas && ./stop.sh && rm -rf ~/.twm && ./play.sh
```
</details>

---

## Desinstalar

Remove **tudo**: processos, serviço, dados das contas e o próprio diretório. Pede confirmação digitando `REMOVER`:

```bash
cd ~/Furia-de-titas && ./uninstall.sh
```

Para remover na mão, sem o script — este comando apaga **todas as pastas** do bot:

```bash
pkill -f twm.sh; pkill -f worker.sh; pkill -f play.sh; sudo systemctl stop twm 2>/dev/null; sudo systemctl disable twm 2>/dev/null; sudo rm -f /etc/systemd/system/twm.service; cd ~ && rm -rf Furia-de-titas ~/.twm ~/twm ~/twm_ANTIGO_NAO_USAR ~/.multcf
```

> Isso apaga as contas cadastradas. As contas **no jogo** não são afetadas.

---

<div align="center">

**Stephenn Curry** · CC0 1.0

</div>
