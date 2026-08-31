Licença CC0 1.0

---

## Dispositivos compatíveis

| Dispositivo | Ambiente |
|---|---|
| Android | Termux (F-Droid) |
| Windows | WSL — Ubuntu |
| iPhone / iPad | iSH |

---

## Instalação — Termux (Android)

Instale o Termux **[pela F-Droid](https://f-droid.org/packages/com.termux/)**. A versão da Play Store não funciona.

Copie e rode **um comando de cada vez**, na ordem:

**1. Atualizar o Termux**
```bash
pkg update && pkg upgrade -y
```

**2. Instalar os programas necessários**
```bash
pkg install git curl wget util-linux coreutils procps tmux -y
```

**3. Manter o aparelho acordado**
```bash
termux-wake-lock
```

**4. Baixar o bot**
```bash
git clone https://github.com/Theoswd/Furia-de-titas.git
```

**5. Entrar na pasta**
```bash
cd Furia-de-titas
```

**6. Dar permissão de execução**
```bash
chmod +x *.sh
```

**7. Cadastrar as contas**
```bash
./setup.sh
```

**8. Iniciar o bot**
```bash
./play.sh
```

> **Pacotes e por que ajudam.** O bot roda sem eles, mas cada um melhora a
> execução: `util-linux` traz o `setsid` (o worker vira líder de grupo, então
> `./stop.sh` encerra a conta inteira sem deixar processo órfão); `procps` traz
> `pgrep`/`pkill` (redes de segurança do stop mais confiáveis); `coreutils` traz
> `date`/`stat`/`readlink`/`sleep` completos (as pausas fracionadas de 0,3–0,5 s
> na batalha e as pequenas leituras de estado); `tmux` mantém o painel vivo se a
> janela fechar. O `jq` **não é usado** pelo bot e pode ser omitido.

> **Permissão de bateria.** Vá em **Configurações → Bateria → Termux** e marque **"Sem restrições"**. Sem isso o Android encerra o bot em segundo plano.

---

## Instalação — WSL (Windows)

Copie e rode **um comando de cada vez**, na ordem:

**1. Atualizar a lista de pacotes**
```bash
sudo apt update
```

**2. Instalar os programas necessários**
```bash
sudo apt install -y git curl util-linux procps coreutils tmux
```

**3. Ir para a pasta pessoal** (nunca instale em `/mnt/c`)
```bash
cd ~
```

**4. Baixar o bot**
```bash
git clone https://github.com/Theoswd/Furia-de-titas.git
```

**5. Entrar na pasta**
```bash
cd Furia-de-titas
```

**6. Dar permissão de execução**
```bash
chmod +x *.sh
```

**7. Cadastrar as contas**
```bash
./setup.sh
```

**8. Iniciar o bot**
```bash
./play.sh
```

> **Permissões de arquivo: nunca instale em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões e o arquivo de credenciais fica com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

---

## Instalação — iSH (iPhone / iPad)

Copie e rode **um comando de cada vez**, na ordem:

**1. Atualizar a lista de pacotes**
```bash
apk update
```

**2. Instalar os programas necessários**
```bash
apk add git curl tzdata bash coreutils procps util-linux
```

**3. Ir para a pasta pessoal**
```bash
cd ~
```

**4. Baixar o bot**
```bash
git clone https://github.com/Theoswd/Furia-de-titas.git
```

**5. Entrar na pasta**
```bash
cd Furia-de-titas
```

**6. Dar permissão de execução**
```bash
chmod +x *.sh
```

**7. Cadastrar as contas**
```bash
./setup.sh
```

**8. Iniciar o bot**
```bash
./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. Para uso contínuo, prefira Termux ou WSL.
