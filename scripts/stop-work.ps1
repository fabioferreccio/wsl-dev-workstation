# stop-work.ps1
# Encerra o Ambiente de Trabalho: mata processos, remove symlinks e ejeta W:.

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  AVISO: $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   ENCERRANDO AMBIENTE DE TRABALHO" -ForegroundColor Cyan
Write-Host "============================================================"

# ─────────────────────────────────────────────────────────────
# 1. Fechar VS Code e DataGrip
# ─────────────────────────────────────────────────────────────
Write-Step "[1/5] Fechando IDEs..."
@("Code", "datagrip64", "idea64", "rider64") | ForEach-Object {
    $p = Get-Process $_ -EA SilentlyContinue
    if ($p) { $p | Stop-Process -Force; Write-OK "$_ encerrado." }
}

# ─────────────────────────────────────────────────────────────
# 2. Docker
# ─────────────────────────────────────────────────────────────
Write-Step "[2/5] Encerrando Docker Desktop..."
Stop-Service -Name "com.docker.service" -Force -EA SilentlyContinue
Get-Process | Where-Object { $_.Name -like "*Docker*" } | Stop-Process -Force -EA SilentlyContinue
Write-OK "Docker encerrado."

# ─────────────────────────────────────────────────────────────
# 3. WSL
# ─────────────────────────────────────────────────────────────
Write-Step "[3/5] Desligando WSL (liberando RAM)..."
wsl --shutdown
Write-OK "WSL desligado."

# ─────────────────────────────────────────────────────────────
# 4. Remover Symlinks (evitar links quebrados no Explorer)
# ─────────────────────────────────────────────────────────────
Write-Step "[4/5] Removendo Symlinks..."

function Remove-Symlink {
    param([string]$LinkPath, [string]$Label)
    $item = Get-Item $LinkPath -Force -EA SilentlyContinue
    if ($null -eq $item) { return }
    if ($item.Attributes -match "ReparsePoint") {
        Remove-Item $LinkPath -Force -Recurse -EA SilentlyContinue
        Write-OK "Symlink removido: $Label ($LinkPath)"
    }
}

Remove-Symlink -LinkPath "C:\Program Files\Git" -Label "Git"
Remove-Symlink -LinkPath "$env:LOCALAPPDATA\Programs\Microsoft VS Code" -Label "VS Code"
Remove-Symlink -LinkPath "$env:USERPROFILE\.gemini\antigravity" -Label "Antigravity"

# ─────────────────────────────────────────────────────────────
# 5. Ejetar VHDX (Unidade W:)
# ─────────────────────────────────────────────────────────────
Write-Step "[5/5] Ejetando Unidade de Trabalho (W:)..."
$vhdxPath = "C:\Worker\work-disk.vhdx"
if (Test-Path "W:\") {
    $dp = "select vdisk file=`"$vhdxPath`"`r`ndetach vdisk"
    $tmp = "$env:TEMP\dp_detach.txt"
    $dp | Out-File -FilePath $tmp -Encoding ASCII
    diskpart /s $tmp | Out-Null
    Remove-Item $tmp
    Write-OK "Unidade W: ejetada."
} else {
    Write-OK "Unidade W: ja estava inativa."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "   AMBIENTE ENCERRADO. PC em modo Lazer. Bom descanso!" -ForegroundColor Yellow
Write-Host "============================================================"
Write-Host ""