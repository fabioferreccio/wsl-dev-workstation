# finish-antigravity-migration.ps1
# Script final para migrar o Antigravity após ele ser fechado pelo usuário.
# Execute como Administrador APÓS fechar o Antigravity.

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Fail { param([string]$msg) Write-Host "  ERRO: $msg" -ForegroundColor Red; exit 1 }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   FINALIZANDO MIGRACAO DO ANTIGRAVITY" -ForegroundColor Cyan
Write-Host "============================================================"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Execute como Administrador."
}

$agSrc = "$env:USERPROFILE\.gemini\antigravity"
$agDst = "W:\Apps\Antigravity"

# 1. Verificar que W: está montado
if (-not (Test-Path "W:\")) {
    Write-Fail "Unidade W: nao esta montada. Execute: manage.bat > [2] Iniciar Workstation"
}

# 2. Verificar que o Antigravity está fechado
$agProc = Get-Process -Name "*antigravity*","*gemini*" -EA SilentlyContinue
if ($agProc) {
    Write-Host "`n  ATENCAO: O Antigravity ainda parece estar em execucao!" -ForegroundColor Red
    Write-Host "  Processos encontrados:" -ForegroundColor Yellow
    $agProc | ForEach-Object { Write-Host "    - $($_.Name) (PID: $($_.Id))" -ForegroundColor Gray }
    $force = Read-Host "`n  Deseja forcar o encerramento? (S/[N])"
    if ($force -eq "S" -or $force -eq "s") {
        $agProc | Stop-Process -Force
        Start-Sleep -Seconds 2
        Write-OK "Antigravity encerrado forcadamente."
    } else {
        Write-Host "  Feche o Antigravity manualmente e execute este script novamente." -ForegroundColor Yellow
        exit 0
    }
}

# 3. Sincronização final (garante dados mais recentes)
Write-Step "[1/3] Sincronizando dados mais recentes do Antigravity..."
if (-not (Test-Path $agSrc)) {
    Write-Fail "Pasta de origem nao encontrada: $agSrc"
}
$null = New-Item -ItemType Directory -Path $agDst -Force
robocopy $agSrc $agDst /MIR /NFL /NDL /NJH /NJS /NC /NS | Out-Null
Write-OK "Dados sincronizados para W:\Apps\Antigravity"

# 4. Remover pasta original e criar symlink
Write-Step "[2/3] Criando Symlink $agSrc --> $agDst..."

$geminiDir = "$env:USERPROFILE\.gemini"
# Remove antigravity original (já temos o backup em W:)
Remove-Item $agSrc -Recurse -Force
# Cria symlink para o W:
cmd /c "mklink /D `"$agSrc`" `"$agDst`"" | Out-Null
Write-OK "Symlink criado: $agSrc --> $agDst"

# 5. Instruções para reinício
Write-Step "[3/3] Concluido!"
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   ANTIGRAVITY MIGRADO COM SUCESSO!" -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""
Write-Host " O Antigravity agora reside em: W:\Apps\Antigravity" -ForegroundColor Gray
Write-Host " O caminho original ($agSrc) aponta para W: via symlink." -ForegroundColor Gray
Write-Host ""
Write-Host " PROXIMO PASSO: Reinicie o Antigravity normalmente." -ForegroundColor Cyan
Write-Host " Ele ira carregar os dados do mesmo local de sempre," -ForegroundColor Cyan
Write-Host " mas agora armazenados em W:." -ForegroundColor Cyan
Write-Host ""
