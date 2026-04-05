# restore-from-work-drive.ps1
# Restaura links, PATH e menus de contexto a partir de um W: Drive ja populado.
# Ideal para novas maquinas, sandboxes ou apos formatacao.

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param([string]$msg) Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  AVISO: $msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$msg) Write-Host "  ERRO: $msg" -ForegroundColor Red; exit 1 }

# -------------------------------------------------------------
# Helper: Adicionar ao PATH (User level p/ evitar admin se possivel)
# -------------------------------------------------------------
function Add-ToPath {
    param([string]$PathToAdd)
    if (-not (Test-Path $PathToAdd)) { return }
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$PathToAdd*") {
        Write-Host "  Adicionando ao PATH: $PathToAdd" -ForegroundColor Yellow
        [Environment]::SetEnvironmentVariable("Path", $currentPath + ";" + $PathToAdd, "User")
        $env:Path += ";" + $PathToAdd
    }
}

# -------------------------------------------------------------
# Verificacoes iniciais
# -------------------------------------------------------------
$isSandbox = ($env:USERNAME -eq "WDAGUtilityAccount")

if (-not (Test-Path "W:\") -and -not $isSandbox) {
    Write-Fail "Unidade W: nao encontrada. Monte o VHDX primeiro."
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   RESTAURACAO: Ambientes de Trabalho" -ForegroundColor Cyan
if ($isSandbox) { Write-Host "   MODO: Windows Sandbox (Links ignorados, apenas config)" -ForegroundColor Yellow }
Write-Host "============================================================"

# -------------------------------------------------------------
# Helper: Criar Symlink Forcado
# -------------------------------------------------------------
function Force-Symlink {
    param([string]$From, [string]$To, [string]$Label)
    
    # No Sandbox, as pastas ja estao mapeadas via .wsb em caminhos fixos.
    if ($isSandbox) { return $true }

    if (-not (Test-Path $To)) {
        Write-Warn "$Label nao encontrado em $To. Pulando link."
        return $false
    }

    if (Test-Path $From) {
        $item = Get-Item $From -Force -EA SilentlyContinue
        if ($item.Attributes -match "ReparsePoint") {
            Write-OK "$($Label): Link ja existe em $From"
            return $true
        } else {
            Write-Warn "$($Label): Pasta ja existe em $From mas nao e link. Removendo para vincular ao W:..."
            Remove-Item $From -Recurse -Force -EA SilentlyContinue
        }
    }

    $parent = Split-Path $From
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    Write-Host "  Vinculando $($Label): $From -> $To" -ForegroundColor Yellow
    cmd /c "mklink /D `"$From`" `"$To`"" | Out-Null
    return $true
}

# -------------------------------------------------------------
# 1. Git
# -------------------------------------------------------------
Write-Step "[1/4] Restaurando Git..."
$gitSrc = "W:\Apps\Git"
$gitDst = "C:\Program Files\Git"

if (Force-Symlink -From $gitDst -To $gitSrc -Label "Git") {
    Add-ToPath "$gitDst\cmd"
    Add-ToPath "$gitDst\bin"
    
    # Menu de Contexto Completo: Git Bash Here
    Write-Host "  Registrando 'Git Bash Here'..." -ForegroundColor Yellow
    $regPaths = @(
        "HKCU:\Software\Classes\Directory\shell\git_bash",
        "HKCU:\Software\Classes\Directory\Background\shell\git_bash"
    )
    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "(Default)" -Value "Git Bash Here"
        Set-ItemProperty -Path $path -Name "Icon" -Value "$gitDst\git-bash.exe"
        $cPath = "$path\command"
        if (-not (Test-Path $cPath)) { New-Item -Path $cPath -Force | Out-Null }
        if ($path -like "*Background*") {
            Set-ItemProperty -Path $cPath -Name "(Default)" -Value "`"$gitDst\git-bash.exe`" --cd=`"%v.`""
        } else {
            Set-ItemProperty -Path $cPath -Name "(Default)" -Value "`"$gitDst\git-bash.exe`" --cd=`"%1`""
        }
    }
    Write-OK "Git pronto."
}

# -------------------------------------------------------------
# 2. VS Code
# -------------------------------------------------------------
Write-Step "[2/4] Restaurando VS Code..."
$vsCodeSrc = "W:\Apps\VSCode"
# No Sandbox o VS Code esta mapeado no AppData local do WDAGUtilityAccount
if ($isSandbox) {
    $vsCodeDst = "C:\Users\WDAGUtilityAccount\AppData\Local\Programs\Microsoft VS Code"
} else {
    $vsCodeDst = "$env:LOCALAPPDATA\Programs\Microsoft VS Code"
}

if (Force-Symlink -From $vsCodeDst -To $vsCodeSrc -Label "VS Code") {
    Add-ToPath "$vsCodeDst\bin"
    
    Write-Host "  Registrando 'Open with Code'..." -ForegroundColor Yellow
    $codeExe = "$vsCodeDst\Code.exe"
    $regPaths = @(
        "HKCU:\Software\Classes\*\shell\vscode",
        "HKCU:\Software\Classes\Directory\shell\vscode",
        "HKCU:\Software\Classes\Directory\Background\shell\vscode"
    )
    foreach ($path in $regPaths) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "(Default)" -Value "Open with Code"
        Set-ItemProperty -Path $path -Name "Icon" -Value "$codeExe,0"
        $cPath = "$path\command"
        if (-not (Test-Path $cPath)) { New-Item -Path $cPath -Force | Out-Null }
        if ($path -like "*Background*") {
            Set-ItemProperty -Path $cPath -Name "(Default)" -Value "`"$codeExe`" `"%V`""
        } else {
            Set-ItemProperty -Path $cPath -Name "(Default)" -Value "`"$codeExe`" `"%1`""
        }
    }
    Write-OK "VS Code pronto."
}

# -------------------------------------------------------------
# 3. Docker (Apenas Host)
# -------------------------------------------------------------
if (-not $isSandbox) {
    Write-Step "[3/4] Docker Data-Root"
    $dockerCfg = "$env:APPDATA\Docker\settings.json"
    if (Test-Path $dockerCfg) {
        $cfg = Get-Content $dockerCfg -Raw | ConvertFrom-Json
        if ($cfg.dataFolder -ne "W:\DockerData") {
            $cfg.dataFolder = "W:\DockerData"
            $cfg | ConvertTo-Json -Depth 20 | Set-Content $dockerCfg -Encoding UTF8
            Write-OK "Docker configurado para usar W:\DockerData"
        } else {
            Write-OK "Docker ja configurado."
        }
    }
} else {
    Write-Step "[3/4] Docker (Pulando no Sandbox)"
}

# -------------------------------------------------------------
# 4. Atalhos no Desktop
# -------------------------------------------------------------
Write-Step "[4/4] Atualizando atalhos no Desktop..."
$WshShell = New-Object -ComObject WScript.Shell
$desktop = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")

# VS Code Shortcut
if (Test-Path "$vsCodeDst\Code.exe") {
    $Shortcut = $WshShell.CreateShortcut("$desktop\VSCode.lnk")
    $Shortcut.TargetPath = "$vsCodeDst\Code.exe"
    if ($isSandbox) {
        $Shortcut.WorkingDirectory = "C:\Users\WDAGUtilityAccount\Desktop\Projects"
    } else {
        $Shortcut.WorkingDirectory = $desktop
    }
    $Shortcut.Save()
}

# PowerShell (Admin) Shortcut
$Shortcut = $WshShell.CreateShortcut("$desktop\PowerShell (Admin).lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -NoExit -Command Set-Location '$desktop'"
$Shortcut.Description = "Abrir PowerShell como Administrador"
$Shortcut.Save()

# Definir bit de 'Executar como Administrador' no arquivo .lnk (Offset 21, bit 0x20)
try {
    $bytes = [System.IO.File]::ReadAllBytes("$desktop\PowerShell (Admin).lnk")
    $bytes[21] = $bytes[21] -bor 0x20
    [System.IO.File]::WriteAllBytes("$desktop\PowerShell (Admin).lnk", $bytes)
    Write-OK "Atalho PowerShell (Admin) criado."
} catch {
    Write-Warn "Nao foi possivel definir bit de Admin no atalho. O comando continuara funcionando."
}

# Git Bash Shortcut (se nao estiver no Sandbox)
if (-not $isSandbox -and (Test-Path "$gitDst\git-bash.exe")) {
    $Shortcut = $WshShell.CreateShortcut("$desktop\Git Bash.lnk")
    $Shortcut.TargetPath = "$gitDst\git-bash.exe"
    $Shortcut.Save()
}

Write-OK "Atalhos atualizados."

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "   RESTAURACAO CONCLUIDA!" -ForegroundColor Green
Write-Host "============================================================"
