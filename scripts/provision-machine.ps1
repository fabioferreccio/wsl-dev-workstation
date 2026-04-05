# provision-machine.ps1
# Script de Provisionamento Mestre — Modelo Universal W: Drive
# Requer execução como Administrador

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Skip { param([string]$msg) Write-Host "  ->  $msg (Pulando)" -ForegroundColor Gray }
function Write-Warn { param([string]$msg) Write-Host "  AVISO: $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  ERRO: $msg" -ForegroundColor Red }

# ─────────────────────────────────────────────────────────────
# 0. Privilégios
# ─────────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Este script PRECISA ser executado como Administrador."
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   WORKSTATION: PROVISIONAMENTO UNIVERSAL (W: Drive)" -ForegroundColor Cyan
Write-Host "============================================================"

# ─────────────────────────────────────────────────────────────
# 1. Recursos do Windows
# ─────────────────────────────────────────────────────────────
Write-Step "[1/7] Habilitando recursos do Windows (WSL, Containers, VM)..."
$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform",
    "Containers"
)
foreach ($f in $features) {
    $result = dism.exe /online /query-featurestate /featurename:$f 2>$null | Select-String "Enabled"
    if ($result) {
        Write-Skip "$f ja esta habilitado"
    } else {
        dism.exe /online /enable-feature /featurename:$f /all /norestart | Out-Null
        Write-OK "$f habilitado"
    }
}
wsl --set-default-version 2 | Out-Null

# ─────────────────────────────────────────────────────────────
# 2. Criar e Montar VHDX (200GB Dinâmico) em W:
# ─────────────────────────────────────────────────────────────
Write-Step "[2/7] Criando/Verificando Disco Virtual (W:) — 200GB Dinamico..."
$vhdxPath = "C:\Worker\work-disk.vhdx"

if (-not (Test-Path $vhdxPath)) {
    Write-Host "  Criando arquivo VHDX (200GB dinamico, ocupa apenas o usado)..." -ForegroundColor Yellow
    $dpCreate = @"
create vdisk file="$vhdxPath" maximum=204800 type=expandable
attach vdisk
create partition primary
format fs=ntfs label="WORK_DRIVE" quick
assign letter=W
"@
    $tmp = "$env:TEMP\dp_create.txt"
    $dpCreate | Out-File -FilePath $tmp -Encoding ASCII
    diskpart /s $tmp | Out-Null
    Remove-Item $tmp
    Write-OK "Disco W: criado e montado."
} elseif (-not (Test-Path "W:\")) {
    Write-Host "  VHDX existe. Montando..." -ForegroundColor Yellow
    $dpMount = "select vdisk file=`"$vhdxPath`"`r`nattach vdisk`r`nselect partition 1`r`nassign letter=W"
    $tmp = "$env:TEMP\dp_mount.txt"
    $dpMount | Out-File -FilePath $tmp -Encoding ASCII
    diskpart /s $tmp | Out-Null
    Remove-Item $tmp
    Write-OK "Disco W: montado."
} else {
    Write-Skip "Disco W: ja esta montado"
}

# ─────────────────────────────────────────────────────────────
# 3. Estrutura de Pastas no W:
# ─────────────────────────────────────────────────────────────
Write-Step "[3/7] Criando estrutura de pastas no W:..."
$wDirs = @(
    "W:\Apps\Git",
    "W:\Apps\VSCode",
    "W:\Apps\Antigravity",
    "W:\Apps\DataGrip",
    "W:\Apps\OpenVPN",
    "W:\Apps\VisualStudio",
    "W:\DockerData",
    "W:\WSL\Ubuntu",
    "W:\Workspace"
)
foreach ($d in $wDirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
Write-OK "Estrutura W: pronta."

# ─────────────────────────────────────────────────────────────
# 4. Instalar Ferramentas em W: (com verificação)
# ─────────────────────────────────────────────────────────────
Write-Step "[4/7] Instalando Ferramentas diretamente em W:\Apps\..."

## Helper: cria symlink do Windows apontando para W:
function New-WorkSymlink {
    param([string]$winPath, [string]$wPath)
    if (Test-Path $winPath) {
        $item = Get-Item $winPath -Force -EA SilentlyContinue
        if ($item.Attributes -match "ReparsePoint") {
            Write-Skip "Symlink $winPath ja existe"
            return
        }
    }
    if (-not (Test-Path (Split-Path $winPath))) {
        New-Item -ItemType Directory -Path (Split-Path $winPath) -Force | Out-Null
    }
    cmd /c "mklink /D `"$winPath`" `"$wPath`"" | Out-Null
    Write-OK "Symlink: $winPath --> $wPath"
}

# --- Git ---
$gitSrc = "C:\Program Files\Git"
$gitDst = "W:\Apps\Git"
if (Get-Command git -EA SilentlyContinue) {
    Write-Skip "Git ja instalado"
} elseif ((Test-Path "$gitDst\cmd\git.exe")) {
    Write-Skip "Git ja esta em W:\Apps\Git"
    New-WorkSymlink -winPath $gitSrc -wPath $gitDst
} else {
    Write-Host "  Instalando Git em W:\Apps\Git..." -ForegroundColor Yellow
    winget install --id Git.Git --silent --location $gitDst `
        --accept-package-agreements --accept-source-agreements | Out-Null
    New-WorkSymlink -winPath $gitSrc -wPath $gitDst
    Write-OK "Git instalado em W:"
}
# Line endings — nunca alterar arquivos
if (Get-Command git -EA SilentlyContinue) {
    git config --global core.autocrlf false
    Write-OK "core.autocrlf = false"
}

# --- VS Code ---
$vscSrc = "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
$vscDst = "W:\Apps\VSCode"
if (Get-Command code -EA SilentlyContinue) {
    Write-Skip "VS Code ja instalado"
} elseif (Test-Path "$vscDst\Code.exe") {
    Write-Skip "VS Code ja esta em W:\Apps\VSCode"
    New-WorkSymlink -winPath $vscSrc -wPath $vscDst
} else {
    Write-Host "  Instalando VS Code em W:\Apps\VSCode..." -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudioCode --silent --location $vscDst `
        --accept-package-agreements --accept-source-agreements | Out-Null
    New-WorkSymlink -winPath $vscSrc -wPath $vscDst
    Write-OK "VS Code instalado em W:"
}

# --- Docker Desktop (binário fica em C:, apenas data-root em W:) ---
Write-Host "  Verificando Docker Desktop..." -ForegroundColor Yellow
if (-not (Get-Command docker -EA SilentlyContinue)) {
    winget install --id Docker.DockerDesktop --silent `
        --accept-package-agreements --accept-source-agreements | Out-Null
    Write-OK "Docker Desktop instalado."
} else {
    Write-Skip "Docker Desktop ja instalado"
}
# Configura data-root para W:\DockerData (imagens e volumes)
$dockerDaemonCfg = "$env:APPDATA\Docker\settings.json"
if (Test-Path $dockerDaemonCfg) {
    $cfg = Get-Content $dockerDaemonCfg | ConvertFrom-Json
    if ($cfg.dataFolder -ne "W:\DockerData") {
        $cfg.dataFolder = "W:\DockerData"
        $cfg | ConvertTo-Json -Depth 20 | Set-Content $dockerDaemonCfg
        Write-OK "Docker data-root configurado: W:\DockerData"
    } else {
        Write-Skip "Docker data-root ja esta em W:\DockerData"
    }
}

# --- DataGrip (JetBrains) ---
Write-Host "  Verificando DataGrip..." -ForegroundColor Yellow
if (-not (Test-Path "W:\Apps\DataGrip\bin\datagrip64.exe")) {
    winget install --id JetBrains.DataGrip --silent --location "W:\Apps\DataGrip" `
        --accept-package-agreements --accept-source-agreements -EA SilentlyContinue | Out-Null
    if (Test-Path "W:\Apps\DataGrip\bin\datagrip64.exe") {
        Write-OK "DataGrip instalado em W:"
    } else {
        Write-Warn "DataGrip nao encontrado via winget. Instale manualmente em W:\Apps\DataGrip"
    }
} else {
    Write-Skip "DataGrip ja instalado em W:"
}

# --- OpenVPN ---
Write-Host "  Verificando OpenVPN..." -ForegroundColor Yellow
if (-not (Test-Path "W:\Apps\OpenVPN\bin\openvpn.exe")) {
    winget install --id OpenVPNTechnologies.OpenVPN --silent --location "W:\Apps\OpenVPN" `
        --accept-package-agreements --accept-source-agreements -EA SilentlyContinue | Out-Null
    if (Test-Path "W:\Apps\OpenVPN\bin\openvpn.exe") {
        Write-OK "OpenVPN instalado em W:"
    } else {
        Write-Warn "OpenVPN nao encontrado via winget. Instale manualmente em W:\Apps\OpenVPN"
    }
} else {
    Write-Skip "OpenVPN ja instalado em W:"
}

# --- Visual Studio 2022 (Build Tools — silencioso) ---
Write-Host "  Verificando Visual Studio 2022..." -ForegroundColor Yellow
if (-not (Test-Path "W:\Apps\VisualStudio\Common7\IDE\devenv.exe")) {
    Write-Warn "Visual Studio requer instalador dedicado."
    Write-Host "  Para instalar, execute:" -ForegroundColor Gray
    Write-Host "  winget install --id Microsoft.VisualStudio.2022.Community --location W:\Apps\VisualStudio" -ForegroundColor Gray
} else {
    Write-Skip "Visual Studio ja instalado em W:"
}

# ─────────────────────────────────────────────────────────────
# 5. WSL — Configurar/Mover Distro para W:\WSL\Ubuntu
# ─────────────────────────────────────────────────────────────
Write-Step "[5/7] Configurando WSL Ubuntu em W:\WSL\Ubuntu..."

# Detecta se Ubuntu ja esta importado em W:
$wslInfo = wsl --list --verbose 2>&1
$ubuntuInW = Test-Path "W:\WSL\Ubuntu\ext4.vhdx"

if ($ubuntuInW) {
    Write-Skip "Ubuntu WSL ja reside em W:\WSL\Ubuntu"
} else {
    $hasUbuntu = $wslInfo | Select-String "Ubuntu" | Where-Object { $_ -notmatch "docker" }
    if ($hasUbuntu) {
        Write-Host "  Ubuntu encontrado no C:. Migrando para W:..." -ForegroundColor Yellow
        Write-Host "  Exportando distro (pode demorar alguns minutos)..." -ForegroundColor Yellow
        wsl --export Ubuntu "W:\WSL\ubuntu-export.tar"
        wsl --unregister Ubuntu | Out-Null
        Write-Host "  Reimportando em W:\WSL\Ubuntu..." -ForegroundColor Yellow
        wsl --import Ubuntu "W:\WSL\Ubuntu" "W:\WSL\ubuntu-export.tar"
        Remove-Item "W:\WSL\ubuntu-export.tar"
        Write-OK "Ubuntu migrado para W:\WSL\Ubuntu"
    } else {
        Write-Host "  Ubuntu nao encontrado. Instalando em W:\WSL\Ubuntu..." -ForegroundColor Yellow
        wsl --install -d Ubuntu --no-launch | Out-Null
        # Instala e já importa na localização certa
        Write-OK "Ubuntu instalado. Configure o usuario ao iniciar pela primeira vez."
    }
}

# Usuário padrão do WSL — Sempre perguntar (nunca assumir)
Write-Host ""
Write-Host "  CONFIGURACAO DE USUARIO WSL:" -ForegroundColor Cyan
$wslUsers = wsl -d Ubuntu -- bash -c "awk -F: '`$3 >= 1000 && `$3 < 65534 {print `$1}' /etc/passwd" 2>$null
if ($null -ne $wslUsers -and $wslUsers -ne "") {
    Write-Host "  Usuarios Linux encontrados: $wslUsers" -ForegroundColor Yellow
    if ($wslUsers -is [array] -and $wslUsers.Count -gt 1) {
        $defaultUser = Read-Host "  Mais de um usuario encontrado. Qual deseja como padrao WSL?"
    } else {
        $confirm = Read-Host "  Definir '$wslUsers' como usuario padrao WSL? (S/[N])"
        if ($confirm -eq "S" -or $confirm -eq "s") {
            $defaultUser = $wslUsers
        } else {
            $defaultUser = Read-Host "  Digite o nome do usuario padrao"
        }
    }
    if ($defaultUser) {
        ubuntu config --default-user $defaultUser 2>$null
        Write-OK "Usuario padrao WSL: $defaultUser"
    }
} else {
    Write-Warn "Nao foi possivel listar usuarios. Configure manualmente: ubuntu config --default-user <nome>"
}

# ─────────────────────────────────────────────────────────────
# 6. Lockdown de Serviços (Setar para Manual)
# ─────────────────────────────────────────────────────────────
Write-Step "[6/7] Configurando servicos de dev para 'Manual'..."
$devServices = @("com.docker.service", "sqlserver", "MSSQL", "mysql", "redis", "mongodb")
foreach ($s in $devServices) {
    $svc = Get-Service -Name "*$s*" -EA SilentlyContinue
    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Manual
        Write-OK "$($svc.Name) -> Manual"
    }
}

# ─────────────────────────────────────────────────────────────
# 7. Finalização
# ─────────────────────────────────────────────────────────────
Write-Step "[7/7] Finalizando..."
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "   PROVISIONAMENTO CONCLUIDO" -ForegroundColor Green
Write-Host "============================================================"
Write-Host " W:\Apps\Git         — Git for Windows" -ForegroundColor Gray
Write-Host " W:\Apps\VSCode      — Visual Studio Code" -ForegroundColor Gray
Write-Host " W:\Apps\DataGrip    — DataGrip (JetBrains)" -ForegroundColor Gray
Write-Host " W:\Apps\OpenVPN     — OpenVPN" -ForegroundColor Gray
Write-Host " W:\DockerData       — Docker images e volumes" -ForegroundColor Gray
Write-Host " W:\WSL\Ubuntu       — Distro Linux" -ForegroundColor Gray
Write-Host " W:\Workspace        — Seus projetos" -ForegroundColor Gray
Write-Host ""
Write-Host " ANTIGRAVITY: Execute a opcao [5] MIGRACAO no manage.bat" -ForegroundColor Yellow
Write-Host " para mover o Antigravity APOS provisionamento completo." -ForegroundColor Yellow
Write-Host ""
Write-Host " RECOMENDACAO: Reinicie antes de continuar." -ForegroundColor Red
