# init-inside-sandbox.ps1
# Executado automaticamente ao iniciar o Windows Sandbox.
# Git e VS Code são mapeados do W: Drive — nenhum download necessário.

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   SANDBOX: Configurando Ambiente Isolado" -ForegroundColor Cyan
Write-Host "============================================================"

# 1. Configurar PATH com ferramentas mapeadas do host (W: via MappedFolders)
Write-Host "[1/3] Configurando PATH..." -ForegroundColor Yellow
$env:Path += ";C:\Program Files\Git\cmd"
$env:Path += ";C:\Program Files\Git\bin"
$env:Path += ";C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Microsoft VS Code\bin"
$env:Path += ";C:\Windows\Microsoft.NET\Framework64\v4.0.30319"
$env:HOME = "C:\Users\WDAGUtilityAccount"
Write-Host "  OK: PATH configurado." -ForegroundColor Green

# 2. SSH Keys (copiadas do host via MappedFolder .ssh)
Write-Host "[2/3] Verificando chaves SSH..." -ForegroundColor Yellow
$sshSrc = "C:\Users\WDAGUtilityAccount\.ssh"
if (Test-Path $sshSrc) {
    # Corrigir permissões das chaves (Windows exige permissão restrita para SSH)
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
} else {
    Write-Host "  AVISO: Pasta .ssh nao encontrada." -ForegroundColor Yellow
}

# 3. Atalho do VS Code no Desktop
Write-Host "[3/3] Criando atalhos..." -ForegroundColor Yellow
$vscodeBin = "C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Microsoft VS Code\Code.exe"
if (Test-Path $vscodeBin) {
    $WshShell   = New-Object -ComObject WScript.Shell
    $Shortcut   = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\VSCode.lnk")
    $Shortcut.TargetPath = $vscodeBin
    $Shortcut.Save()
    Write-Host "  OK: Atalho VS Code criado." -ForegroundColor Green
} else {
    Write-Host "  AVISO: VS Code nao mapeado. Verifique se W: estava montado ao abrir o Sandbox." -ForegroundColor Yellow
}

# Posicionar no projeto
$projectsDir = "C:\Users\WDAGUtilityAccount\Desktop\Projects"
if (Test-Path $projectsDir) { Set-Location $projectsDir }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "   SANDBOX PRONTO!" -ForegroundColor Green
Write-Host "   Git e VS Code disponiveis. Projetos em Desktop\Projects." -ForegroundColor Gray
Write-Host "   LEMBRE: Nada salvo em C:\ dentro do Sandbox persiste!" -ForegroundColor Yellow
Write-Host "============================================================"