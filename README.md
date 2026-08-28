# Fúria de Titãs

Bot multi-contas para **[Fúria de Titãs](https://furiadetitas.net)**.

Licença CC0 1.0

---

## Aviso

Automação viola os termos de uso do jogo e pode resultar em **banimento das contas**. Você assume esse risco.

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

```bash
pkg update && pkg upgrade -y
pkg install git curl wget jq util-linux -y
termux-wake-lock
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
chmod +x *.sh
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> **Permissão de bateria.** Vá em **Configurações → Bateria → Termux** e marque **"Sem restrições"**. Sem isso o Android encerra o bot em segundo plano.

---

## Instalação — WSL (Windows)

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
cd ~
git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
chmod +x *.sh
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> **Permissões de arquivo: nunca instale em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões e o arquivo de credenciais fica com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

---

## Instalação — iSH (iPhone / iPad)

```bash
apk update && apk add git curl jq tzdata bash
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
chmod +x *.sh
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. Para uso contínuo, prefira Termux ou WSL.
