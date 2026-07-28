# 🎵 Baixador de Mídia Inteligente Pro

Uma interface gráfica simples em **PowerShell + Windows Forms** para baixar vídeos, playlists e áudios do YouTube (e outros sites suportados pelo [yt-dlp](https://github.com/yt-dlp/yt-dlp)), com seleção individual de itens, escolha de formato (MP3/MP4) e log de progresso em tempo real.

Não é necessário instalar Python, yt-dlp ou FFmpeg manualmente — o próprio script cuida disso na primeira execução.

![Plataforma](https://img.shields.io/badge/plataforma-Windows-blue)
![Licença](https://img.shields.io/badge/licença-MIT-green)

---

## ✨ Funcionalidades

- 📋 Cole o link de um vídeo **ou** de uma playlist inteira.
- 🔎 Botão **Procurar** lista todos os títulos encontrados.
- ✅ Marque/desmarque individualmente o que deseja baixar.
- 🎧 Escolha entre **MP3** (áudio) ou **MP4** (vídeo).
- 📁 Escolha e memorize a pasta de destino entre uma execução e outra.
- 🖥️ Log de progresso do `yt-dlp` exibido dentro do próprio programa.
- ⚙️ **Instalação automática e silenciosa** do `yt-dlp` e do `FFmpeg` na primeira execução (nenhuma janela de terminal aparece).
- 🖱️ Criação automática de um **atalho na Área de Trabalho**, já com o ícone do programa, para uso nas próximas vezes.

---

## 🚀 Como usar

1. Baixe este repositório (botão **Code > Download ZIP**) ou clone-o:
   ```bash
   git clone https://github.com/SEU-USUARIO/BaixadorDeMidiaPro.git
   ```
2. Extraia a pasta, caso tenha baixado o `.zip`.
3. Dê **dois cliques** em `setup.bat`.
4. Na primeira execução, aguarde a configuração automática (o programa baixa o `yt-dlp` e o `FFmpeg` sozinho — isso só acontece uma vez e requer conexão com a internet).
5. Um atalho **"Baixador de Mídia Pro"** será criado na sua Área de Trabalho. Use-o nas próximas vezes.
6. Cole o link, clique em **Procurar**, marque o que quiser baixar, escolha o formato e clique em **BAIXAR AGORA**.

---

## 🧩 Requisitos

- Windows 10 ou superior.
- PowerShell (já incluso no Windows).
- Conexão com a internet na primeira execução (para baixar os componentes) e durante os downloads.

Não é necessário ter Python, yt-dlp ou FFmpeg pré-instalados — tudo é baixado automaticamente para uma pasta local em:
```
%LOCALAPPDATA%\BaixadorDeMidiaPro\bin
```

---

## 🗂️ Estrutura do projeto

```
baixador-de-midia-pro/
├── setup.bat     # Script principal (batch + PowerShell em um único arquivo)
├── icone.ico           # Ícone usado na janela e no atalho da Área de Trabalho
├── README.md
├── LICENSE
└── .gitignore
```

---

## ⚠️ Aviso legal

Este projeto é uma interface para o [yt-dlp](https://github.com/yt-dlp/yt-dlp), uma ferramenta de código aberto amplamente utilizada. Baixar conteúdo protegido por direitos autorais sem autorização pode violar os Termos de Serviço da plataforma de origem e a legislação aplicável. Use esta ferramenta apenas para baixar conteúdo que você tem o direito de baixar (por exemplo, vídeos próprios, conteúdo de domínio público ou licenciado sob Creative Commons).

---

## 📄 Licença

Distribuído sob a licença MIT. Veja [`LICENSE`](LICENSE) para mais detalhes.

---

## 🙌 Créditos

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — motor de download.
- [FFmpeg](https://ffmpeg.org/) — conversão de áudio/vídeo.
- Builds do FFmpeg para Windows fornecidos por [gyan.dev](https://www.gyan.dev/ffmpeg/builds/).
