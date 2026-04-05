# migrate-to-work-drive.ps1
# Migra ferramentas ja instaladas no C: para W: usando robocopy + symlinks.
# Deve ser executado UMA VEZ em maquinas onde as ferramentas foram instaladas antes do W: Drive.
# Requer execucao como Administrador.

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Skip { param([string]$msg) Write-Host "  ->  $msg (Pulando)" -ForegroundColor Gray }
function Write-Warn { param([string]$msg) Write-Host "  AVISO: $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  ERRO: $msg" -ForegroundColor Red; exit 1 }

# -------------------------------------------------------------
# Helper: Fecha processos que estao usando uma pasta
# -------------------------------------------------------------
function Stop-ProcessesInPath {
    param([string]$FolderPath)
    $FolderPath = $FolderPath.TrimEnd('\')
    # Nota: Get-Process .Path pode retornar erro para processos de sistema, ignoramos.
    $procs = Get-Process -EA SilentlyContinue | Where-Object { 
        try { $_.Path -like "$FolderPath*" } catch { $false }
    }
    if ($procs) {
        Write-Host "  Fechando processos ativos em $FolderPath..." -ForegroundColor Yellow
        foreach ($p in $procs) {
            Write-Host "    -> Parando $($p.Name) (PID: $($p.Id))" -ForegroundColor Gray
            $p | Stop-Process -Force -EA SilentlyContinue
        }
        Start-Sleep -Seconds 2
    }
}

# -------------------------------------------------------------
# Verificacoes iniciais
# -------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Execute como Administrador."
}

if (-not (Test-Path "W:\")) {
    Write-Fail "Unidade W: nao esta montada. Execute primeiro: manage.bat > [2] Iniciar Workstation"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   MIGRACAO: C: -> W: Drive (Execucao Unica)" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host " Este script move ferramentas do C: para W: e cria symlinks."
Write-Host " Ferramentas continuarao funcionando normalmente via symlink."
Write-Host ""

# -------------------------------------------------------------
# Helper: Move pasta + cria Symlink
# -------------------------------------------------------------
function Move-ToWorkDrive {
    param(
        [string]$From,   # Caminho original no C:
        [string]$To,     # Destino em W:\Apps\...
        [string]$Label   # Nome amigavel para os logs
    )

    # Ja foi migrado?
    $item = Get-Item $From -Force -EA SilentlyContinue
    if ($item -and $item.Attributes -match "ReparsePoint") {
        Write-Skip "$Label ja foi migrado (symlink existente em $From)"
        return
    }

    if (-not (Test-Path $From)) {
        Write-Skip "$Label nao encontrado em $From"
        return
    }

    # Garantir que nada bloqueia a COPIA tambem
    Stop-ProcessesInPath -FolderPath $From

    Write-Host "  Copiando $Label para $To (isso pode demorar)..." -ForegroundColor Yellow
    if (-not (Test-Path $To)) { $null = New-Item -ItemType Directory -Path $To -Force }
    # /R:3 /W:3 -> Tenta 3 vezes, espera 3 seg (evita hangs infinitos)
    # /MT:16   -> Multithreaded para velocidade
    robocopy $From $To /MIR /NFL /NDL /NJH /NJS /NC /NS /R:3 /W:3 /MT:16 | Out-Null

    Write-Host "  Removendo pasta original $From..." -ForegroundColor Yellow
    Stop-ProcessesInPath -FolderPath $From
    
    $maxRetries = 3
    $retryCount = 0
    $success = $false
    
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Remove-Item $From -Recurse -Force -EA Stop
            $success = $true
        } catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Warn "  Erro ao remover $From. Tentando fechar processos novamente em 2s (Tentativa $retryCount/$maxRetries)..."
                Stop-ProcessesInPath -FolderPath $From
                Start-Sleep -Seconds 2
            }
        }
    }

    if (-not $success) {
        Write-Fail "Nao foi possivel remover $From. Certifique-se de fechar todos os programas e tente novamente."
    }

    Write-Host "  Criando symlink $From -> $To..." -ForegroundColor Yellow
    cmd /c "mklink /D `"$From`" `"$To`"" | Out-Null
    Write-OK "$Label migrado com sucesso."
}

# -------------------------------------------------------------
# 1. Git
# -------------------------------------------------------------
Write-Step "[1/5] Migrando Git..."
Move-ToWorkDrive -From "C:\Program Files\Git" -To "W:\Apps\Git" -Label "Git"
if (Get-Command git -EA SilentlyContinue) {
    git config --global core.autocrlf false
    Write-OK "Git: core.autocrlf = false"
}

# -------------------------------------------------------------
# 2. VS Code
# -------------------------------------------------------------
Write-Step "[2/5] Migrando VS Code..."
# Fechar VS Code antes de mover
$codeProc = Get-Process code -EA SilentlyContinue
if ($codeProc) {
    Write-Host "  Fechando VS Code..." -ForegroundColor Yellow
    $codeProc | Stop-Process -Force
    Start-Sleep -Seconds 2
}
Move-ToWorkDrive `
    -From "$env:LOCALAPPDATA\Programs\Microsoft VS Code" `
    -To "W:\Apps\VSCode" `
    -Label "VS Code"

# -------------------------------------------------------------
# 3. Docker - apenas data-root
# -------------------------------------------------------------
Write-Step "[3/5] Configurando Docker data-root para W:\DockerData..."
$dockerDaemonCfg = "$env:APPDATA\Docker\settings.json"
if (Test-Path $dockerDaemonCfg) {
    $cfgRaw = Get-Content $dockerDaemonCfg -Raw
    $cfg = $cfgRaw | ConvertFrom-Json
    if ($cfg.dataFolder -ne "W:\DockerData") {
        $cfg.dataFolder = "W:\DockerData"
        $cfg | ConvertTo-Json -Depth 20 | Set-Content $dockerDaemonCfg -Encoding UTF8
        Write-OK "Docker data-root -> W:\DockerData"
    } else {
        Write-Skip "Docker data-root ja esta em W:\DockerData"
    }
} else {
    Write-Warn "settings.json do Docker nao encontrado."
}

# -------------------------------------------------------------
# 4. WSL Ubuntu
# -------------------------------------------------------------
Write-Step "[4/5] Migrando WSL Ubuntu para W:\WSL\Ubuntu..."
$ubuntuInW = Test-Path "W:\WSL\Ubuntu\ext4.vhdx"

if ($ubuntuInW) {
    Write-Skip "Ubuntu ja reside em W:\WSL\Ubuntu"
} else {
    $wslInfo = wsl --list --verbose 2>&1
    $hasUbuntu = $wslInfo | Select-String "Ubuntu" | Where-Object { $_ -notmatch "docker" }
    if ($hasUbuntu) {
        Write-Host "  Exportando Ubuntu (isso pode demorar)..." -ForegroundColor Yellow
        if (-not (Test-Path "W:\WSL\Ubuntu")) { $null = New-Item -ItemType Directory -Path "W:\WSL\Ubuntu" -Force }
        wsl --export Ubuntu "W:\WSL\ubuntu-export.tar"
        wsl --unregister Ubuntu | Out-Null
        Write-Host "  Reimportando em W:\WSL\Ubuntu..." -ForegroundColor Yellow
        wsl --import Ubuntu "W:\WSL\Ubuntu" "W:\WSL\ubuntu-export.tar"
        Remove-Item "W:\WSL\ubuntu-export.tar" -Force
        wsl --set-default Ubuntu | Out-Null

        Write-Host "  VALIDACAO DE USUARIO WSL:" -ForegroundColor Cyan
        $wslUsers = wsl -d Ubuntu -- bash -c "awk -F: '`$3 >= 1000 && `$3 < 65534 {print `$1}' /etc/passwd" 2>$null
        if ($null -ne $wslUsers -and $wslUsers -ne "") {
            $defaultUser = ""
            Write-Host "  Usuarios encontrados: $wslUsers" -ForegroundColor Yellow
            $confirm = Read-Host "  Definir '$wslUsers' como padrao? (S/N) [S]"
            if ($confirm -ne "N" -and $confirm -ne "n") { $defaultUser = $wslUsers }
            else { $defaultUser = Read-Host "  Digite o nome do usuario" }
            
            if ($defaultUser) {
                ubuntu config --default-user $defaultUser 2>$null
                Write-OK "Usuario padrao WSL: $defaultUser"
            }
        }
        Write-OK "Ubuntu migrado."
    }
}

# -------------------------------------------------------------
# 5. Antigravity - ULTIMO
# -------------------------------------------------------------
Write-Step "[5/5] Antigravity - Migracao em 2 Etapas"
$agSrc = "$env:USERPROFILE\.gemini\antigravity"
$agDst = "W:\Apps\Antigravity"

if (Test-Path $agSrc) {
    Write-Host "  Copiando dados do Antigravity para W:..." -ForegroundColor Yellow
    if (-not (Test-Path $agDst)) { $null = New-Item -ItemType Directory -Path $agDst -Force }
    robocopy $agSrc $agDst /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    Write-OK "Dados copiados."
}

Write-Host ""
Write-Host "  PROXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "  1. Feche o Antigravity completamente." -ForegroundColor White
Write-Host "  2. Execute (como Admin):" -ForegroundColor White
Write-Host "     powershell -File C:\Worker\scripts\finish-antigravity-migration.ps1" -ForegroundColor Yellow
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host "   MIGRACAO CONCLUIDA (Antigravity pendente - ver acima)" -ForegroundColor Green
Write-Host "============================================================"
