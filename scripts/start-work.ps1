# start-work.ps1
# Inicia o Ambiente de Trabalho: monta W:, valida symlinks, sobe Docker/WSL.

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  AVISO: $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO AMBIENTE DE TRABALHO" -ForegroundColor Cyan
Write-Host "============================================================"

# ─────────────────────────────────────────────────────────────
# 0. Montar Disco W: via Diskpart
# ─────────────────────────────────────────────────────────────
Write-Step "[0/5] Verificando Unidade de Trabalho (W:)..."
$vhdxPath = "C:\Worker\work-disk.vhdx"

if (Test-Path $vhdxPath) {
    if (-not (Test-Path "W:\")) {
        Write-Host "  Montando disco VHDX..." -ForegroundColor Yellow
        $dp = "select vdisk file=`"$vhdxPath`"`r`nattach vdisk`r`nselect partition 1`r`nassign letter=W"
        $tmp = "$env:TEMP\dp_mount.txt"
        $dp | Out-File -FilePath $tmp -Encoding ASCII
        diskpart /s $tmp | Out-Null
        Remove-Item $tmp
        Start-Sleep -Seconds 2
        Write-OK "Unidade W: montada."
    } else {
        Write-OK "Unidade W: ja esta ativa."
    }
} else {
    Write-Warn "VHDX nao encontrado em $vhdxPath. Execute o Provisionamento primeiro."
}

# ─────────────────────────────────────────────────────────────
# 1. Verificar/Recriar Symlinks (caso ejeção anterior tenha removido)
# ─────────────────────────────────────────────────────────────
Write-Step "[1/5] Verificando Symlinks..."

function Ensure-Symlink {
    param([string]$LinkPath, [string]$Target, [string]$Label)
    if (-not (Test-Path $Target)) { return }   # Ferramenta não instalada em W:, skip
    $item = Get-Item $LinkPath -Force -EA SilentlyContinue
    if ($null -eq $item) {
        # Pasta não existe de forma alguma: criar symlink
        $parent = Split-Path $LinkPath
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        cmd /c "mklink /D `"$LinkPath`" `"$Target`"" | Out-Null
        Write-OK "Symlink recriado: $Label"
    } elseif ($item.Attributes -match "ReparsePoint") {
        Write-OK "Symlink OK: $Label"
    } else {
        Write-Warn "${Label}: pasta local encontrada (nao e symlink). Verifique manualmente."
    }
}

Ensure-Symlink -LinkPath "C:\Program Files\Git" -Target "W:\Apps\Git" -Label "Git"
Ensure-Symlink -LinkPath "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -Target "W:\Apps\VSCode" -Label "VS Code"
Ensure-Symlink -LinkPath "$env:USERPROFILE\.gemini\antigravity" -Target "W:\Apps\Antigravity" -Label "Antigravity"

# ─────────────────────────────────────────────────────────────
# 2. Docker
# ─────────────────────────────────────────────────────────────
Write-Step "[2/5] Iniciando Docker Desktop..."
$dockerSvc = Get-Service -Name "com.docker.service" -EA SilentlyContinue
if ($dockerSvc) {
    if ($dockerSvc.Status -ne "Running") {
        Start-Service -Name "com.docker.service" -EA SilentlyContinue
    }
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerExe) { Start-Process $dockerExe -WindowStyle Hidden }
    Write-OK "Docker iniciado."
} else {
    Write-Warn "Docker Desktop nao encontrado."
}

# ─────────────────────────────────────────────────────────────
# 3. WSL2
# ─────────────────────────────────────────────────────────────
Write-Step "[3/5] Preparando WSL2 (Ubuntu em W:\WSL\Ubuntu)..."
wsl --exec true 2>$null | Out-Null
Write-OK "WSL2 pronto."

# ─────────────────────────────────────────────────────────────
# 4. Túnel SSH (opcional)
# ─────────────────────────────────────────────────────────────
Write-Host ""
$resp = Read-Host "[OPCIONAL] Deseja ligar o tunel SSH agora? (S/[N])"
if ($resp -eq "S" -or $resp -eq "s") {
    Start-Job -ScriptBlock { wsl ssh -N bastion } | Out-Null
    Write-OK "Tunel SSH solicitado em background."
} else {
    Write-Host "  -> Seguindo sem tunel (Padrao)." -ForegroundColor Gray
}

# ─────────────────────────────────────────────────────────────
# 5. VS Code — abre em modo WSL
# ─────────────────────────────────────────────────────────────
Write-Step "[5/5] Abrindo VS Code..."
$wslUser = wsl -d Ubuntu -- whoami 2>$null
if ($wslUser) {
    $projectPath = "/home/$wslUser/projects"
    wsl -d Ubuntu -- mkdir -p $projectPath
    $codeCmd = Get-Command code -EA SilentlyContinue
    if ($codeCmd) {
        code --remote wsl+Ubuntu $projectPath
        Write-OK "VS Code aberto em WSL+Ubuntu."
    } else {
        Write-Warn "VS Code nao encontrado no PATH. Verifique o symlink."
    }
} else {
    Write-Warn "Nao foi possivel detectar usuario WSL. Abra o VS Code manualmente."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   AMBIENTE PRONTO! Bom trabalho." -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""