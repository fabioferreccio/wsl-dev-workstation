# ==========================================================
# SCRIPT DE PONTES UNIFICADO - VERSAO FINAL E RESILIENTE
# ==========================================================

$userLinux = wsl -d Ubuntu whoami
if ($null -eq $userLinux -or $userLinux -eq "") {
    Write-Host "ERRO: Ubuntu nao encontrado." -ForegroundColor Red
    exit
}

$wslBase = "\\wsl.localhost\Ubuntu\home\$userLinux"
$shellApp = New-Object -ComObject shell.application

Write-Host "--- Construindo Infraestrutura de Atalhos ---" -ForegroundColor Cyan

# Funcao para Criar Symlink e Fixar no Acesso Rapido
function Build-Bridge {
    param (
        [string]$winPath,
        [string]$wslPath,
        [string]$label
    )

    # 1. Garante que a pasta pai no Windows existe
    $parent = Split-Path -Path $winPath
    if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    # 2. Remove atalho antigo se existir (seja Junction, Arquivo ou Symlink)
    if (Test-Path $winPath) { 
        $target = Get-Item $winPath -ErrorAction SilentlyContinue
        if ($target.Attributes -match "ReparsePoint") { Remove-Item $winPath -Force -Recurse }
    }
    
    # 3. Cria o Link Simbolico via CMD
    cmd /c "mklink /D ""$winPath"" ""$wslPath"""

    # 4. Tenta fixar no Acesso Rapido
    try {
        $folder = $shellApp.Namespace($winPath)
        if ($null -ne $folder) {
            $folder.Self.InvokeVerb("pintohome")
            Write-Host "OK: ${label} criado e fixado." -ForegroundColor Green
        }
    } catch {
        Write-Host "AVISO: ${label} criado, mas falha ao fixar." -ForegroundColor Yellow
    }
}

# --- EXECUCAO ---

# 1. Projetos (Desktop)
Build-Bridge -winPath "$env:USERPROFILE\Desktop\Projetos_Linux" -wslPath "$wslBase\projects" -label "Projetos"

# 2. SSH Keys (C:\Worker)
Build-Bridge -winPath "C:\Worker\wsl\ssh_links\linux_ssh" -wslPath "$wslBase\.ssh" -label "SSH Keys"

# 3. Kubernetes Config (C:\Worker)
Build-Bridge -winPath "C:\Worker\wsl\k8s_links\linux_kube" -wslPath "$wslBase\.kube" -label "K8s Config"

Write-Host ""
Write-Host "--- TUDO PRONTO! VERIFIQUE O EXPLORER ---" -ForegroundColor Cyan