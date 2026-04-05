# init-inside-sandbox.ps1
# Executado automaticamente ao iniciar o Windows Sandbox.
# Git e VS Code são mapeados do W: Drive — nenhum download necessário.

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   SANDBOX: Configurando Ambiente Isolado" -ForegroundColor Cyan
Write-Host "============================================================"

# 1. Mapeamento e Restauração
Write-Host "[1/2] Restaurando Ambiente (Links, Registro e PATH e Atalhos)..." -ForegroundColor Yellow
# No Sandbox, os drives são mapeados via .wsb em locais fixos.
# O script de restauração em Desktop\Scripts irá garantir que o PATH e o Registro estejam configurados.
powershell -ExecutionPolicy Bypass -File "C:\Users\WDAGUtilityAccount\Desktop\Scripts\restore-from-work-drive.ps1"

# 2. SSH Keys (copiadas do host via MappedFolder .ssh)
Write-Host "[2/2] Verificando chaves SSH..." -ForegroundColor Yellow
$sshSrc = "C:\Users\WDAGUtilityAccount\.ssh"
if (Test-Path $sshSrc) {
    Get-ChildItem $sshSrc -File | ForEach-Object {
        $acl = Get-Acl $_.FullName
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "WDAGUtilityAccount", "FullControl", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl $_.FullName $acl -EA SilentlyContinue
    }
    Write-Host "  OK: Chaves SSH prontas." -ForegroundColor Green
}

# Posicionar no projeto
$projectsDir = "C:\Users\WDAGUtilityAccount\Desktop\Projects"
if (Test-Path $projectsDir) { Set-Location $projectsDir }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   SANDBOX PRONTO!" -ForegroundColor Green
Write-Host "   Git e VS Code (com Menus de Contexto) disponiveis." -ForegroundColor Gray
Write-Host "============================================================"