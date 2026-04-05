Write-Host '--- INICIANDO HARD RESET DO UBUNTU ---' -ForegroundColor Red

# 1. Finaliza processos
Write-Host 'Parando WSL...' -ForegroundColor Gray
wsl --shutdown

# 2. Desinstala a distro (CUIDADO: APAGA TUDO)
Write-Host '[1/3] Removendo instancia Ubuntu...' -ForegroundColor Yellow
wsl --unregister Ubuntu

# 3. Reinstala a distro
Write-Host '[2/3] Reinstalando Ubuntu limpo...' -ForegroundColor Cyan
wsl --install -d Ubuntu --no-launch

# 4. Limpa atalhos antigos (Evita links quebrados)
Write-Host '[3/3] Limpando links antigos no Windows...' -ForegroundColor Cyan
$links = @(
    "$env:USERPROFILE\Desktop\Projetos_Linux",
    "C:\Worker\wsl\ssh_links\linux_ssh",
    "C:\Worker\wsl\k8s_links\linux_kube"
)

foreach ($l in $links) {
    if (Test-Path $l) { 
        $target = Get-Item $l -ErrorAction SilentlyContinue
        if ($target.Attributes -match 'ReparsePoint') { 
            Remove-Item $l -Force -ErrorAction SilentlyContinue
            Write-Host "Link removido: $l" -ForegroundColor Gray
        }
    }
}

Write-Host ''
Write-Host '--- RESET CONCLUIDO COM SUCESSO ---' -ForegroundColor Green
Write-Host '1. Digite `wsl --set-default Ubuntu` e depois `wsl` para criar usuario/senha.'
Write-Host '2. Rode o `cp /mnt/c/Worker/wsl/install-tools.sh ~/install-tools.sh && cd ~ && sed -i 's/\r$//' install-tools.sh && chmod +x install-tools.sh && sudo ./install-tools.sh` no Linux.'
Write-Host '3. Rode o create-shortcuts.ps1 no PowerShell.'