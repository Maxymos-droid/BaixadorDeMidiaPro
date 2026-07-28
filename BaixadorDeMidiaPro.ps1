# --------------------------------------------------------------------------
# --- BAIXADOR DE MÍDIA INTELIGENTE PRO
# --------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --------------------------------------------------------------------------
# --- FUNÇÃO PARA EXTRAIR ÍCONES NATIVOS DO WINDOWS
# --------------------------------------------------------------------------
function Get-WindowsIcon {
    param(
        [Parameter(Mandatory)]
        [int]$Index,
        [string]$Dll = "shell32.dll",
        [int]$Size = 16
    )

    $code = @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;

public class IconExtractor {
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr ExtractIconEx(string lpszFile, int nIconIndex, IntPtr[] phiconLarge, IntPtr[] phiconSmall, int nIcons);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);

    public static Icon GetIcon(string dll, int index, bool large) {
        IntPtr[] largeIcons = new IntPtr[1];
        IntPtr[] smallIcons = new IntPtr[1];
        ExtractIconEx(dll, index, largeIcons, smallIcons, 1);
        IntPtr handle = large ? largeIcons[0] : smallIcons[0];
        if (handle == IntPtr.Zero) return null;
        Icon icon = (Icon)Icon.FromHandle(handle).Clone();
        DestroyIcon(handle);
        return icon;
    }
}
"@

    if (-not ("IconExtractor" -as [type])) {
        Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
    }

    $dllPath = Join-Path $env:SystemRoot "System32\$Dll"
    $icon = [IconExtractor]::GetIcon($dllPath, $Index, ($Size -ge 32))
    if ($icon) { return $icon.ToBitmap() }
    return $null
}

# --------------------------------------------------------------------------
# --- CAMINHOS E CONFIGURAÇÃO GLOBAL
# --------------------------------------------------------------------------
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir  = Split-Path $scriptPath -Parent
$iconPath   = Join-Path $scriptDir 'icone.ico'
$appDataDir = Join-Path $env:LOCALAPPDATA 'BaixadorDeMidiaPro'
$binDir     = Join-Path $appDataDir 'bin'
$flagFile   = Join-Path $appDataDir '.instalado'
$configFile = Join-Path $env:USERPROFILE 'yt_dlp_config.txt'
$global:destFolder = ""

if (-not (Test-Path $appDataDir)) { New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null }
if (-not (Test-Path $binDir))     { New-Item -ItemType Directory -Path $binDir     -Force | Out-Null }

# --------------------------------------------------------------------------
# --- GARANTE QUE NOSSAS CÓPIAS LOCAIS TENHAM PRIORIDADE NESTA SESSÃO
# --------------------------------------------------------------------------
$env:PATH = "$binDir;$env:PATH"

if (Test-Path $configFile) {
    $global:destFolder = (Get-Content $configFile -Raw).Trim()
}

# --------------------------------------------------------------------------
# --- INSTALAÇÃO SILENCIOSA DE COMPONENTES (yt-dlp e FFmpeg)
# --------------------------------------------------------------------------
function Test-Ferramenta($nome) {
    return $null -ne (Get-Command $nome -ErrorAction SilentlyContinue)
}

function Show-Splash($mensagemInicial) {
    $splash = New-Object Windows.Forms.Form
    $splash.Text = 'Configurando o Baixador...'
    $splash.Size = New-Object Drawing.Size(430, 150)
    $splash.StartPosition = 'CenterScreen'
    $splash.FormBorderStyle = 'FixedDialog'
    $splash.ControlBox = $false
    $splash.TopMost = $true

    $lbl = New-Object Windows.Forms.Label
    $lbl.Name = 'lblStatus'
    $lbl.Text = $mensagemInicial
    $lbl.Font = New-Object Drawing.Font('Segoe UI', 10.5)
    $lbl.Dock = 'Fill'
    $lbl.TextAlign = 'MiddleCenter'
    $splash.Controls.Add($lbl)
    $splash.Show()
    $splash.Refresh()
    return $splash
}

function Instalar-Componentes {
    $splash = Show-Splash "Preparando o Baixador de Mídia Pro...`r`nIsso só acontece na primeira execução."
    try {
        if (-not (Test-Ferramenta 'yt-dlp')) {
            $splash.Controls['lblStatus'].Text = "Baixando yt-dlp...`r`nAguarde, isso pode levar alguns segundos."
            $splash.Refresh()
            $ytdlpUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
            Invoke-WebRequest -Uri $ytdlpUrl -OutFile (Join-Path $binDir 'yt-dlp.exe') -UseBasicParsing
        }

        if (-not (Test-Ferramenta 'ffmpeg')) {
            $splash.Controls['lblStatus'].Text = "Baixando FFmpeg...`r`nIsso pode demorar um pouco mais."
            $splash.Refresh()
            $ffUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
            $zipPath = Join-Path $env:TEMP 'ffmpeg_temp_download.zip'
            $extractPath = Join-Path $env:TEMP 'ffmpeg_temp_extract'

            Invoke-WebRequest -Uri $ffUrl -OutFile $zipPath -UseBasicParsing

            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

            $ffmpegExe = Get-ChildItem -Path $extractPath -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
            if ($ffmpegExe) {
                Copy-Item $ffmpegExe.FullName (Join-Path $binDir 'ffmpeg.exe') -Force
                $ffprobeSrc = Join-Path $ffmpegExe.DirectoryName 'ffprobe.exe'
                if (Test-Path $ffprobeSrc) {
                    Copy-Item $ffprobeSrc (Join-Path $binDir 'ffprobe.exe') -Force
                }
            }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
            Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType File -Path $flagFile -Force | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show(
            "Não foi possível baixar automaticamente todos os componentes.`r`n`r`nDetalhe: $($_.Exception.Message)`r`n`r`nVerifique sua conexão com a internet, ou instale manualmente o yt-dlp e o FFmpeg e adicione-os ao PATH do Windows.",
            'Aviso de instalação', 'OK', 'Warning'
        ) | Out-Null
    }
    finally {
        $splash.Close()
    }
}

function Criar-Atalho {
    try {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $atalhoPath = Join-Path $desktop 'Baixador de Mídia Pro.lnk'

        if (Test-Path $atalhoPath) { return }

        $wsh = New-Object -ComObject WScript.Shell
        $atalho = $wsh.CreateShortcut($atalhoPath)

        # Aponta para o .BAT (mais confiável)
        $batPath = Join-Path $scriptDir 'setup.bat'
        $atalho.TargetPath = $batPath
        $atalho.WorkingDirectory = $scriptDir

        if (Test-Path $iconPath) {
            $atalho.IconLocation = "$iconPath,0"
        }

        $atalho.Description = 'Baixador de Mídia Inteligente Pro'
        $atalho.Save()
    }
    catch {
        # Se quiser ver o erro (temporariamente), descomente a linha abaixo:
        [Windows.Forms.MessageBox]::Show("Erro ao criar atalho:`n$($_.Exception.Message)", "Erro")
    }
}

if (-not (Test-Path $flagFile)) {
    Instalar-Componentes
}

# --------------------------------------------------------------------------
# --- SEMPRE TENTA CRIAR O ATALHO (SÓ CRIA SE AINDA NÃO EXISTIR)
# --------------------------------------------------------------------------
Criar-Atalho

# --------------------------------------------------------------------------
# --- DEFINIÇÃO DE FONTES
# --------------------------------------------------------------------------
$fontPrincipal = New-Object Drawing.Font('Segoe UI', 11)
$fontNegrito   = New-Object Drawing.Font('Segoe UI', 11, [Drawing.FontStyle]::Bold)
$fontTitulo    = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$fontBotoes    = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)

# --------------------------------------------------------------------------
# --- CARREGA OS ÍCONES DO WINDOWS
# --------------------------------------------------------------------------
$icoSearch   = Get-WindowsIcon -Index 22    # Lupa
$icoFolder   = Get-WindowsIcon -Index 4     # Pasta
$icoCheck    = Get-WindowsIcon -Index 294   # Check /238 /294
$icoClear    = Get-WindowsIcon -Index 131   # Limpar / X
$icoDownload = Get-WindowsIcon -Index 122   # Download /122 /176 /299
$icoAudio    = Get-WindowsIcon -Index 128   # Alto-falante / Áudio ativo /116/ 128
$icoVideo    = Get-WindowsIcon -Index 129   # Filme / Câmera (bom para MP4)/ 115/ 129

# --------------------------------------------------------------------------
# --- INTERFACE GRÁFICA
# --------------------------------------------------------------------------
$form = New-Object Windows.Forms.Form
$form.Text = 'Baixador de Mídia Inteligente Pro'
$form.Size = New-Object Drawing.Size(600, 750)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
if (Test-Path $iconPath) {
    $form.Icon = New-Object Drawing.Icon($iconPath)
}
$form.Add_FormClosing({
    [System.Environment]::Exit(0)
})

# --------------------------------------------------------------------------
# --- CAMPO DE ENTRADA DO LINK
# --------------------------------------------------------------------------
$label_link = New-Object Windows.Forms.Label
$label_link.Text = 'Cole o link do vídeo ou playlist aqui:'
$label_link.Font = $fontTitulo
$label_link.Location = New-Object Drawing.Point(20, 15)
$label_link.Size = New-Object Drawing.Size(400, 25)
$form.Controls.Add($label_link)

$txt_link = New-Object Windows.Forms.TextBox
$txt_link.Font = $fontPrincipal
$txt_link.Location = New-Object Drawing.Point(20, 45)
$txt_link.Size = New-Object Drawing.Size(390, 28)
$form.Controls.Add($txt_link)

# --------------------------------------------------------------------------
# --- BOTÃO ANALISAR LINK
# --------------------------------------------------------------------------
$btn_load = New-Object Windows.Forms.Button
$btn_load.Text = " Procurar..."
$btn_load.Font = $fontBotoes
$btn_load.Location = New-Object Drawing.Point(430, 44)
$btn_load.Size = New-Object Drawing.Size(130, 30)
$btn_load.Image = $icoSearch
$btn_load.ImageAlign = 'MiddleLeft'
$btn_load.TextImageRelation = 'ImageBeforeText'
$form.Controls.Add($btn_load)

# --------------------------------------------------------------------------
# --- GRUPO DO FORMATO
# --------------------------------------------------------------------------
$group_box = New-Object Windows.Forms.GroupBox
$group_box.Text = ' Configurações de Saída '
$group_box.Font = $fontNegrito
$group_box.Location = New-Object Drawing.Point(20, 90)
$group_box.Size = New-Object Drawing.Size(540, 75)

$rb_mp3 = New-Object Windows.Forms.RadioButton
$rb_mp3.Text = "  (Áudio) MP3"
$rb_mp3.Font = $fontPrincipal
$rb_mp3.Location = New-Object Drawing.Point(20, 30)
$rb_mp3.Size = New-Object Drawing.Size(160, 28)
$rb_mp3.Checked = $true
$rb_mp3.Image = $icoAudio
$rb_mp3.ImageAlign = 'MiddleLeft'
$rb_mp3.TextImageRelation = 'ImageBeforeText'
$group_box.Controls.Add($rb_mp3)

$rb_mp4 = New-Object Windows.Forms.RadioButton
$rb_mp4.Text = "  (Vídeo) MP4"
$rb_mp4.Font = $fontPrincipal
$rb_mp4.Location = New-Object Drawing.Point(200, 30)
$rb_mp4.Size = New-Object Drawing.Size(160, 28)
$rb_mp4.Image = $icoVideo
$rb_mp4.ImageAlign = 'MiddleLeft'
$rb_mp4.TextImageRelation = 'ImageBeforeText'
$group_box.Controls.Add($rb_mp4)

$form.Controls.Add($group_box)

# --------------------------------------------------------------------------
# --- LISTA DE SELEÇÃO DAS MÚSICAS
# --------------------------------------------------------------------------
$label_list = New-Object Windows.Forms.Label
$label_list.Text = 'Músicas encontradas (Desmarque o que não quiser):'
$label_list.Font = $fontTitulo
$label_list.Location = New-Object Drawing.Point(20, 185)
$label_list.Size = New-Object Drawing.Size(450, 25)
$form.Controls.Add($label_list)

$list_box = New-Object Windows.Forms.CheckedListBox
$list_box.Font = $fontPrincipal
$list_box.Location = New-Object Drawing.Point(20, 215)
$list_box.Size = New-Object Drawing.Size(540, 150)
$list_box.CheckOnClick = $true
$form.Controls.Add($list_box)

# --------------------------------------------------------------------------
# --- BOTÕES RÁPIDOS
# --------------------------------------------------------------------------
$btn_select_all = New-Object Windows.Forms.Button
$btn_select_all.Text = " Marcar Todos"
$btn_select_all.Font = $fontBotoes
$btn_select_all.Location = New-Object Drawing.Point(20, 380)
$btn_select_all.Size = New-Object Drawing.Size(140, 30)
$btn_select_all.Image = $icoCheck
$btn_select_all.ImageAlign = 'MiddleLeft'
$btn_select_all.TextImageRelation = 'ImageBeforeText'
$btn_select_all.Add_Click({ for($i=0; $i -lt $list_box.Items.Count; $i++) { $list_box.SetItemChecked($i, $true) } })
$form.Controls.Add($btn_select_all)

$btn_unselect_all = New-Object Windows.Forms.Button
$btn_unselect_all.Text = " Limpar Seleção"
$btn_unselect_all.Font = $fontBotoes
$btn_unselect_all.Location = New-Object Drawing.Point(170, 380)
$btn_unselect_all.Size = New-Object Drawing.Size(140, 30)
$btn_unselect_all.Image = $icoClear
$btn_unselect_all.ImageAlign = 'MiddleLeft'
$btn_unselect_all.TextImageRelation = 'ImageBeforeText'
$btn_unselect_all.Add_Click({ for($i=0; $i -lt $list_box.Items.Count; $i++) { $list_box.SetItemChecked($i, $false) } })
$form.Controls.Add($btn_unselect_all)

# --------------------------------------------------------------------------
# --- PASTA DE DESTINO MEMORIZADA
# --------------------------------------------------------------------------
$label_folder = New-Object Windows.Forms.Label
$label_folder.Text = "Pasta atual: $global:destFolder"
$label_folder.Font = $fontPrincipal
$label_folder.Location = New-Object Drawing.Point(20, 430)
$label_folder.Size = New-Object Drawing.Size(540, 25)
$form.Controls.Add($label_folder)

$btn_folder = New-Object Windows.Forms.Button
$btn_folder.Text = " Alterar Pasta"
$btn_folder.Font = $fontBotoes
$btn_folder.Location = New-Object Drawing.Point(20, 460)
$btn_folder.Size = New-Object Drawing.Size(140, 32)
$btn_folder.Image = $icoFolder
$btn_folder.ImageAlign = 'MiddleLeft'
$btn_folder.TextImageRelation = 'ImageBeforeText'
$btn_folder.Add_Click({
    $fbd = New-Object Windows.Forms.FolderBrowserDialog
    if ($fbd.ShowDialog() -eq 'OK') {
        $global:destFolder = $fbd.SelectedPath
        $global:destFolder | Out-File $configFile -Encoding ascii -Force
        $label_folder.Text = "Pasta atual: $global:destFolder"
    }
})
$form.Controls.Add($btn_folder)

# --------------------------------------------------------------------------
# --- TERMINAL DE LOGS INTEGRADO
# --------------------------------------------------------------------------
$label_log = New-Object Windows.Forms.Label
$label_log.Text = ' Progresso do Terminal:'
$label_log.Font = $fontTitulo
$label_log.Location = New-Object Drawing.Point(20, 510)
$label_log.Size = New-Object Drawing.Size(250, 25)
$form.Controls.Add($label_log)

$txt_log = New-Object Windows.Forms.TextBox
$txt_log.Location = New-Object Drawing.Point(20, 540)
$txt_log.Size = New-Object Drawing.Size(540, 110)
$txt_log.Multiline = $true
$txt_log.ScrollBars = 'Vertical'
$txt_log.ReadOnly = $true
$txt_log.BackColor = [System.Drawing.Color]::Black
$txt_log.ForeColor = [System.Drawing.Color]::LimeGreen
$txt_log.Font = New-Object Drawing.Font('Consolas', 10)
$form.Controls.Add($txt_log)

# --------------------------------------------------------------------------
# --- BOTÃO BAIXAR DESTACADO
# --------------------------------------------------------------------------
$btn_download = New-Object Windows.Forms.Button
$btn_download.Text = "  BAIXAR AGORA"
$btn_download.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$btn_download.Location = New-Object Drawing.Point(390, 660)
$btn_download.Size = New-Object Drawing.Size(170, 40)
$btn_download.Image = $icoDownload
$btn_download.ImageAlign = 'MiddleLeft'
$btn_download.TextImageRelation = 'ImageBeforeText'
$form.Controls.Add($btn_download)

# --------------------------------------------------------------------------
# --- FASE 1: EXTRAIR OS TÍTULOS
# --------------------------------------------------------------------------
$btn_load.Add_Click({
    if ($txt_link.Text -eq '') {
        [Windows.Forms.MessageBox]::Show('Por favor, insira um link antes de analisar.', 'Aviso')
        return
    }
    $btn_load.Enabled = $false
    $txt_log.Text = "Conectando... Mapeando playlist.`r`n"
    $list_box.Items.Clear()
    [System.Windows.Forms.Application]::DoEvents()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'yt-dlp'
    $psi.Arguments = @('--flat-playlist', '--print', '%(title)s', $txt_link.Text)
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    if ($proc.Start()) {
        while (!$proc.HasExited) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line) {
                [void]$list_box.Items.Add($line, $true)
                [System.Windows.Forms.Application]::DoEvents()
            }
        }
    }
    $txt_log.AppendText("Análise concluída! Encontrados: $($list_box.Items.Count) item(ns).`r`n")
    $btn_load.Enabled = $true
})

# --------------------------------------------------------------------------
# --- FASE 2: BAIXAR VIA ÍNDICES DA PLAYLIST
# --------------------------------------------------------------------------
$btn_download.Add_Click({
    if ($list_box.CheckedItems.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show('Selecione pelo menos um vídeo na lista marcando a caixinha.', 'Aviso')
        return
    }
    if ($global:destFolder -eq '') {
        [Windows.Forms.MessageBox]::Show('Escolha uma pasta de destino clicando em Alterar Pasta.', 'Aviso')
        return
    }

    $btn_download.Enabled = $false
    $btn_folder.Enabled   = $false
    $btn_load.Enabled     = $false

    $urlGeral = $txt_link.Text

    for ($i = 0; $i -lt $list_box.Items.Count; $i++) {
        if ($list_box.GetItemChecked($i)) {
            $trackTitle    = $list_box.Items[$i]
            $playlistIndex = $i + 1

            $txt_log.Text = "Baixando ($playlistIndex/$($list_box.Items.Count)): $trackTitle`r`n"
            [System.Windows.Forms.Application]::DoEvents()

            $args = @('-P', $global:destFolder, '--playlist-items', [string]$playlistIndex)

            if ($rb_mp3.Checked) {
                $args += @('-x', '--audio-format', 'mp3', '--audio-quality', '0', $urlGeral)
            } else {
                $args += @('-f', 'bv*[ext=mp4]+ba[ext=m4a]/mp4', $urlGeral)
            }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'yt-dlp'
            $psi.Arguments = $args
            $psi.WorkingDirectory = $global:destFolder
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            if ($proc.Start()) {
                while (!$proc.HasExited) {
                    $line = $proc.StandardOutput.ReadLine()
                    if ($line -and ($line.Contains('%') -or $line.Contains('Destination'))) {
                        $txt_log.AppendText($line + "`r`n")
                        $txt_log.SelectionStart = $txt_log.TextLength
                        $txt_log.ScrollToCaret()
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                }
                while ($line = $proc.StandardOutput.ReadLine()) {
                    $txt_log.AppendText($line + "`r`n")
                }
            }
        }
    }

    [Windows.Forms.MessageBox]::Show('Downloads selecionados concluídos com sucesso!', 'Sucesso', 'OK', 'Information')
    $txt_log.Text = "Pronto para receber um novo link."
    $list_box.Items.Clear()
    $txt_link.Text = ""

    $btn_download.Enabled = $true
    $btn_folder.Enabled   = $true
    $btn_load.Enabled     = $true
})

$form.ShowDialog() | Out-Null