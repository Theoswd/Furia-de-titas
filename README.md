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
sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**6.** Cadastre as contas:

```bash
./setup.sh
```

**7.** Inicie:

```bash
./play.sh
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
sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**5.** Cadastre as contas:

```bash
./setup.sh
```

**6.** Inicie:

```bash
./play.sh
```

> Para o bot continuar rodando depois de fechar o terminal, use `tmux`:
>
> ```bash
> sudo apt install -y tmux && tmux new -s twm
> ```
>
> Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.

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
sha256sum -c .integrity --quiet && echo "Scripts integros"
```

**4.** Cadastre as contas:

```bash
./setup.sh
```

**5.** Inicie:

```bash
./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. A emulação também é lenta. Para uso contínuo, prefira Termux ou WSL.

---

## Comandos

| O quê | Comando |
|---|---|
| Iniciar | `./play.sh` |
| Parar tudo | `./stop.sh` |
| Cadastrar contas | `./setup.sh` |
| Diagnosticar login | `./diagnose.sh` |
| Ver log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |

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
cd ~/Furia-de-titas && sha256sum *.sh | sort -k2 > .integrity
```

---

## Solução de problemas

<details>
<summary><b>A conta não loga / fica presa em "login..."</b></summary>

Rode o diagnóstico. Ele mostra o que o servidor responde e **nunca exibe a senha**:

```bash
./diagnose.sh
```

Depois com o número da conta:

```bash
./diagnose.sh 1
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
./stop.sh && pkill -f twm.sh && ./play.sh
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
