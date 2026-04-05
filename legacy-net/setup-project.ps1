# setup-project.ps1
$slnFile = Get-ChildItem *.sln | Select-Object -First 1
if ($null -eq $slnFile) { Write-Error "Nenhum .sln encontrado!"; return }

$projectName = $slnFile.BaseName
$vscodeDir = Join-Path (Get-Location) ".vscode"
if (!(Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir | Out-Null }

$tasksJson = @{
    version = "2.0.0"
    tasks = @(@{
        label = "Build Debug ($projectName)"
        type = "shell"
        command = "msbuild"
        args = @("${projectName}.sln", "/p:Configuration=Debug", "/t:Rebuild")
        group = "build"
        problemMatcher = "`$msCompile"
    })
} | ConvertTo-Json -Depth 10

$tasksJson | Set-Content -Path (Join-Path $vscodeDir "tasks.json") -Encoding UTF8
Write-Host "✔ Configuração gerada para $projectName" -ForegroundColor Green