$wslConfigPath = "$env:USERPROFILE\.wslconfig"

$configContent = @"
[wsl2]
# Memória: 8GB é ideal para quem tem 32GB (Sobra muito para o Windows/Jogos)
memory=8GB 

# Processadores: Limitamos a 2 núcleos para garantir que o Windows nunca trave
processors=2

# Liberação de Memória: Força o Linux a devolver RAM para o Windows gradualmente
autoMemoryReclaim=gradual

# Performance de Disco: SSD se beneficia de swap desativado (evita desgaste e lentidão)
swap=0

# Networking: Melhora a conexão entre Windows e Linux
localhostForwarding=true

# Modo de rede esparsa (ajuda a reduzir uso de RAM do Vmmem)
sparseVhd=true
"@

Write-Host "--- Otimizando Infraestrutura WSL2 ---" -ForegroundColor Cyan

# Cria ou sobrescreve o arquivo
Set-Content -Path $wslConfigPath -Value $configContent -Encoding UTF8

Write-Host "✔ Arquivo .wslconfig criado em: $wslConfigPath" -ForegroundColor Green
Write-Host "✔ Configuração aplicada: 8GB RAM | 2 CPUs | Swap Off" -ForegroundColor Gray

# Reinicia o WSL para aplicar
Write-Host "--- Reiniciando Subsistema para Aplicar Mudanças ---" -ForegroundColor Yellow
wsl --shutdown

Write-Host "--- TUDO PRONTO! ---" -ForegroundColor Green
Write-Host "O processo VmmemWSL agora será domado." -ForegroundColor White