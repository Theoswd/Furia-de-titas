# Fúria de Titãs

Bot multi-contas para **[Fúria de Titãs](https://furiadetitas.net)**.

**Autoria: Stephenn Curry** · Licença CC0 1.0

---

## Aviso

Automação viola os termos de uso do jogo e pode resultar em **banimento das contas**. Você assume esse risco.

---

## Instalação — Termux (Android)

Instale o Termux **[pela F-Droid](https://f-droid.org/packages/com.termux/)**. A versão da Play Store não funciona.

```bash
pkg update && pkg upgrade -y
pkg install git curl wget jq util-linux -y
termux-wake-lock
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> Vá também em **Configurações → Bateria → Termux** e marque **"Sem restrições"**.

---

## Instalação — WSL (Windows)

```bash
sudo apt update && sudo apt install -y git curl jq util-linux procps
cd ~
git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> **Nunca instale em `/mnt/c`.** Em pastas do Windows o Linux não aplica permissões e o arquivo de credenciais fica com acesso liberado. Confira com `pwd` — deve começar com `/home/`.

> Para continuar rodando depois de fechar o terminal, use `tmux`: `sudo apt install -y tmux && tmux new -s twm`. Rode o `./play.sh` dentro da sessão e saia com **Ctrl+B** depois **D**. Para voltar: `tmux attach -t twm`.

---

## Instalação — iSH (iPhone / iPad)

```bash
apk update && apk add git curl jq tzdata bash
cd ~ && git clone https://github.com/Theoswd/Furia-de-titas.git && cd Furia-de-titas
sha256sum -c .integrity --quiet && echo "Scripts integros"
./setup.sh
./play.sh
```

> **O iOS suspende aplicativos em segundo plano.** O bot para quando você sai do iSH ou bloqueia a tela, e não há como evitar isso. Para uso contínuo, prefira Termux ou WSL.

---

## Comandos

| O quê | Comando |
|---|---|
| Iniciar | `cd ~/Furia-de-titas && ./play.sh` |
| **Ver o painel** (não mexe nas contas) | `cd ~/Furia-de-titas && ./status.sh` |
| Rodar as atividades agora | `cd ~/Furia-de-titas && ./agora.sh` |
| Pausar / retomar | `cd ~/Furia-de-titas && ./pause.sh` |
| Parar tudo | `cd ~/Furia-de-titas && ./stop.sh` |
| Cadastrar contas | `cd ~/Furia-de-titas && ./setup.sh` |
| Deslogar todas as contas | `cd ~/Furia-de-titas && ./logout.sh` |
| Diagnosticar login | `cd ~/Furia-de-titas && ./diagnose.sh` |
| **Relatório de saúde** (uma tela, tudo) | `cd ~/Furia-de-titas && ./saude.sh` |
| Conferir os dados de uma conta | `cd ~/Furia-de-titas && ./lerstats.sh NomeDaConta` |
| Ver a página da Masmorra do Clã | `cd ~/Furia-de-titas && ./lerstats.sh NomeDaConta masmorra` |
| Ver log de uma conta | `tail -f ~/.twm/BR_NomeConta/twm.log` |
| Desinstalar | `cd ~/Furia-de-titas && ./uninstall.sh` |

---

## Atualização

```bash
cd ~/Furia-de-titas && ./stop.sh && git pull && sha256sum -c .integrity --quiet && ./play.sh
```

As contas cadastradas e os dados em `~/.twm` não são afetados — só os scripts.

> **Reiniciar faz parte da atualização.** Cada conta lê os scripts uma única vez, ao subir. Um `git pull` sozinho troca os arquivos no disco, mas as contas que já estavam no ar seguem com o código antigo — use o comando acima, que já para e sobe de novo. O `./saude.sh` avisa (`PROC on/old`) quando isso acontece.

> **O painel também.** O `./status.sh` lê o layout uma vez, quando sobe. Deixado aberto durante a atualização — típico no WSL, onde ele fica num painel do `tmux` —, continua desenhando a versão antiga. O `./stop.sh` agora o encerra junto, e o próprio painel avisa `codigo atualizado — feche e abra o painel` quando está defasado.

---

## Melhorias desta versão

**Multi-contas**
- Cada conta roda em instância própria: diretório, sessão, credencial, configuração e log separados.
- A última conta do `accounts.conf` era ignorada em silêncio quando o arquivo não terminava em quebra de linha.
- Login serializado entre as contas, para o servidor não recusar a rajada do mesmo IP.
- Cada conta usa um User-Agent próprio.
- Falha de rede no login deixou de ser tratada como senha errada — antes isso parava a conta por até 15 minutos.

**Sessão**
- A sessão é revalidada durante o ócio, e não só nos horários da agenda. Antes a conta aparecia no painel mas não no jogo.
- Entre os ciclos a conta descansa de fato na página inicial.
- Reconexões saem espaçadas entre as contas, para uma queda não virar uma rajada de logins do mesmo IP.

**Estabilidade**
- Menos processos por requisição: 16 contas cabem no limite de 32 processos do Android 12+ sem o encerramento por *signal 9*.
- O painel foi separado do orquestrador: abrir e fechar o `./status.sh` não derruba conta nenhuma.
- Log de cada conta com rotação, e todo laço de batalha com teto de tempo.

**Eventos**
- Horários conferidos contra o cronograma do jogo; inscrição 5 minutos antes em todos.
- Coliseu do Clã recuperou 3 dos 5 minutos de inscrição e só se inscreve quando a temporada está aberta.
- Corrigido o defeito que fazia a conta abandonar a luta no meio do evento.
- Durante os cinco eventos de prioridade nenhuma outra atividade roda.
- A agenda oficial do jogo passou a ser lida de verdade.

**Atividades**
- Arena, carreira, campanha, caverna, cabana do sábio, liga, troca, missões e masmorra revisadas contra o projeto original.
- Liga, Troca, Missões do Clã e Eventos passaram a rodar também fora dos minutos da agenda.
- Missões concluídas voltaram a ser recolhidas; o mercador do clã faz as três produções.
- Masmorra do Clã deixou de depender de hora fixa: procura o golpe na própria página e insiste enquanto houver acesso livre.
- O bot nunca gasta ouro.

**Painel**
- Atividade de cada conta visível, e batalha em andamento em destaque.
- No bloco **AO VIVO — BATALHAS**, o registro da luta aparece logo abaixo do nome: quem acertou a conta, com quanto, se foi crítico, e a habilidade, erva ou pedra que a conta usou.
- Larguras adaptadas à tela: o HP deixou de ser empurrado para fora do campo de visão no celular.
- Energia, HP, ouro e prata deixaram de ficar congelados; o painel avisa quando os números estão parados.
- Atualização a cada 5 segundos.

> Mais (ou menos) linhas do registro da luta: `PANEL_LOG_LINHAS=4 ./status.sh` — `0` desliga.

**Diagnóstico**
- `./saude.sh` põe numa tela só o que costuma ser perguntado num diagnóstico remoto: memória, processos, sessão e log de cada conta.
- Ele avisa quando as contas ficaram rodando o código anterior a um `git pull` sem reinício.
- `./lerstats.sh` mostra a página crua que o bot lê, para comparar com o navegador quando um número não bate.

---

## Integridade

O arquivo `.integrity` guarda a soma SHA-256 de cada script.

```bash
cd ~/Furia-de-titas && sha256sum -c .integrity --quiet && echo "Nenhum script foi alterado"
```

Se algum arquivo estiver diferente, restaure com `git checkout -- . && git pull`.

---

<div align="center">

**Stephenn Curry** · CC0 1.0

</div>
