# launch-sandbox.ps1
# Gera e abre o Windows Sandbox com ferramentas mapeadas do W: Drive.
# Requer que W: esteja montado (rode start-work.ps1 primeiro).

$workerPath    = "C:\Worker"
$projectsPath  = "$workerPath\projects_legacy"
$sshPath       = "$env:USERPROFILE\.ssh"

# Ferramentas vêm do W: — não precisa instalar nada dentro do Sandbox
$vscodePath    = "W:\Apps\VSCode"
$gitPath       = "W:\Apps\Git"
$toolsPath     = "$workerPath\legacy-net"

# Garantir que pastas existam
foreach ($p in @($projectsPath, $sshPath)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# Verificar se W: está disponível
if (-not (Test-Path $vscodePath)) {
    Write-Host "AVISO: W:\Apps\VSCode nao encontrado." -ForegroundColor Yellow
    Write-Host "Certifique-se de rodar o Provisionamento ou a Migracao primeiro." -ForegroundColor Yellow
    # Fallback para VS Code local se ainda existir
    $vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
}
if (-not (Test-Path $gitPath)) {
    $gitPath = "C:\Program Files\Git"
}

$xml  = "<Configuration>"
$xml += "<MappedFolders>"

# VS Code (somente leitura — executavel compartilhado)
if (Test-Path $vscodePath) {
    $xml += "<MappedFolder>"
    $xml += "<HostFolder>$vscodePath</HostFolder>"
    $xml += "<SandboxFolder>C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Microsoft VS Code</SandboxFolder>"
    $xml += "<ReadOnly>true</ReadOnly>"
    $xml += "</MappedFolder>"
}

# Git (somente leitura)
if (Test-Path $gitPath) {
    $xml += "<MappedFolder>"
    $xml += "<HostFolder>$gitPath</HostFolder>"
    $xml += "<SandboxFolder>C:\Program Files\Git</SandboxFolder>"
    $xml += "<ReadOnly>true</ReadOnly>"
    $xml += "</MappedFolder>"
}

# Scripts e ferramentas internas
$xml += "<MappedFolder>"
$xml += "<HostFolder>$toolsPath</HostFolder>"
$xml += "<SandboxFolder>C:\Users\WDAGUtilityAccount\Desktop\Tools</SandboxFolder>"
$xml += "<ReadOnly>false</ReadOnly>"
$xml += "</MappedFolder>"

# Projetos legados (leitura/escrita — persistente no host)
$xml += "<MappedFolder>"
$xml += "<HostFolder>$projectsPath</HostFolder>"
$xml += "<SandboxFolder>C:\Users\WDAGUtilityAccount\Desktop\Projects</SandboxFolder>"
$xml += "<ReadOnly>false</ReadOnly>"
$xml += "</MappedFolder>"

# Chaves SSH (leitura/escrita)
$xml += "<MappedFolder>"
$xml += "<HostFolder>$sshPath</HostFolder>"
$xml += "<SandboxFolder>C:\Users\WDAGUtilityAccount\.ssh</SandboxFolder>"
$xml += "<ReadOnly>false</ReadOnly>"
$xml += "</MappedFolder>"

$xml += "</MappedFolders>"
$xml += "<LogonCommand><Command>C:\Users\WDAGUtilityAccount\Desktop\Tools\entrypoint.bat</Command></LogonCommand>"
$xml += "</Configuration>"

$tempWsb = "$workerPath\legacy-net\temp-dev-legacy.wsb"
$xml | Set-Content -Path $tempWsb -Encoding UTF8
Start-Process $tempWsb

Write-Host "Sandbox iniciado. Git e VS Code mapeados de W:\Apps\" -ForegroundColor Cyan
Write-Host "Seus projetos estao em Desktop\Projects (persistente)." -ForegroundColor Gray