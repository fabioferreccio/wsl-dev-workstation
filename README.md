# 🚀 Workstation: O Manual de Arquiteto

Repositório de automação para transformar qualquer PC Windows em uma **workstation de desenvolvimento profissional**, separando totalmente o **Modo Trabalho** do **Modo Lazer**.

A filosofia é simples:
- Quando você trabalha, o PC é uma máquina potente com Linux, Docker, IDEs e ferramentas prontas.
- Quando você quer jogar (ou só usar o PC normalmente), o PC **"esquece" o ambiente de trabalho** — zero serviços, zero consumo, 100% do hardware para você.

---

## 🧠 Conceitos Fundamentais

| Conceito | O que é |
|---|---|
| **WSL2** | Linux dentro do Windows. Ambiente de desenvolvimento moderno sem dual-boot. |
| **Docker** | Containers para rodar infraestrutura (BD, Redis, APIs) de forma isolada. |
| **W: Drive (VHDX)** | Disco virtual de 200GB onde **todas** as ferramentas de dev vivem. Ao ejetar, o PC volta a ser "limpo". |
| **Symlinks** | Atalhos que fazem o Windows "achar" que as ferramentas estão no `C:\`, mas elas vivem no `W:`. |
| **Windows Sandbox** | Ambiente Windows completamente isolado e descartável para tarefas arriscadas ou legado .NET. |

---

## 🏗️ Estrutura do Arquivo `work-disk.vhdx` (W: Drive)

```
W:\
├── Apps\
│   ├── Git\              ← Git for Windows
│   ├── VSCode\           ← Visual Studio Code
│   ├── Antigravity\      ← Gemini Antigravity (IA)
│   ├── DataGrip\         ← JetBrains DataGrip
│   ├── OpenVPN\          ← Cliente VPN
│   └── VisualStudio\     ← Visual Studio 2022 (Legado .NET)
├── DockerData\           ← Imagens e volumes Docker
├── WSL\
│   └── Ubuntu\           ← Distro Linux completa
└── Workspace\            ← Projetos (opcional)
```

**Por que isso é poderoso para escala (20+ máquinas)?**
Você configura o `W:` perfeitamente em uma máquina e copia o arquivo `work-disk.vhdx` para todas as outras. O script de provisionamento apenas cria os symlinks — tudo já está instalado e configurado.

---

## 📦 Estrutura do Repositório `C:\Worker`

```
C:\Worker\
├── manage.bat                  ← PONTO DE ENTRADA ÚNICO (Painel de Controle)
├── work-disk.vhdx              ← Disco de Trabalho (gerado no provisionamento)
│
├── scripts\
│   ├── provision-machine.ps1           ← Setup completo de uma nova máquina
│   ├── migrate-to-work-drive.ps1       ← Migra tools já instaladas do C: para W:
│   ├── finish-antigravity-migration.ps1 ← Etapa final da migração do Antigravity
│   ├── start-work.ps1                  ← Liga o ambiente de trabalho
│   ├── stop-work.ps1                   ← Desliga e ejeta tudo
│   ├── create-shortcuts.ps1            ← Cria atalhos no Explorer
│   └── optimize-wsl.ps1                ← Otimiza consumo de RAM do WSL
│
├── legacy-net\
│   ├── launch-sandbox.ps1      ← Abre o Windows Sandbox com tools mapeadas
│   ├── init-inside-sandbox.ps1 ← Configuração automática dentro do Sandbox
│   └── entrypoint.bat          ← Ponto de entrada do Sandbox
│
├── wsl\
│   ├── install-tools.sh        ← Setup do Ubuntu (NVM, Kubectl, Git config)
│   └── ssh-config              ← Configuração SSH/Bastion
│
└── containers\
    └── generic-dev-env\
        └── devcontainer.json   ← Dev Container global (.NET 8)
```

---

## 🛠️ Passo 0: Pré-requisitos (Instalação Manual, uma vez)

> Estes passos são necessários apenas uma vez no Windows principal.
> Depois disso, tudo é automatizado.

```powershell
# Como Administrador — habilitar WSL e recursos de virtualização
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Containers /all /norestart
Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -All
# Reinicie o computador após esses comandos
```

Após o reinício:
- **Clonar este repositório em `C:\Worker`**: `git clone <url> C:\Worker`
- **Copiar o `work-disk.vhdx`** de outra máquina configurada (se existir), ou deixar o provisionamento criar um novo.

---

## 🚀 Fluxo de Provisionamento (Nova Máquina)

Tudo é controlado pelo **Painel de Controle**:

```
C:\Worker\manage.bat
```

### [1] PROVISIONAMENTO — Setup Inicial

Execute a opção `[1]` no `manage.bat`. O script:
1. Habilita WSL2, Containers e VM no Windows
2. Cria o `work-disk.vhdx` de 200GB (dinâmico) e monta como `W:`
3. Cria a estrutura de pastas em `W:`
4. Instala Git, VS Code, DataGrip, OpenVPN **diretamente em `W:\Apps\`**
5. Configura Docker para salvar imagens em `W:\DockerData`
6. Move ou instala o Ubuntu WSL em `W:\WSL\Ubuntu`
7. Cria Symlinks no `C:\` apontando para `W:\Apps\`
8. Congela serviços de dev em modo Manual (não iniciam no boot)

> 💡 **Se as ferramentas já estavam instaladas no C:**, use a opção `[5] MIGRAÇÃO`.

### [5] MIGRAÇÃO — Máquina com tools no C:

Para máquinas onde Git, VS Code, etc. já foram instalados no `C:\`, use a opção `[5]`:
- Move cada ferramenta para `W:` usando `robocopy`
- Cria symlinks para manter compatibilidade
- **Antigravity é migrado em 2 etapas** (processo em uso): o script guia você

---

## ☀️ Início do Dia de Trabalho

```
manage.bat → [2] INICIAR
```

O que acontece:
1. Monta `W:` via diskpart
2. Verifica/recria symlinks (caso tenham sido removidos pelo Stop)
3. Inicia Docker Desktop
4. Acorda o WSL2
5. Pergunta sobre túnel SSH/Bastion
6. Abre VS Code conectado ao Ubuntu

---

## 🎮 Fim do Dia / Modo Lazer

```
manage.bat → [3] ENCERRAR
```

O que acontece:
1. Fecha VS Code, DataGrip e outras IDEs
2. Para o Docker (serviço e processos)
3. Desliga o WSL (libera RAM do `VmmemWSL`)
4. **Remove os Symlinks** do `C:\` (Git, VS Code, Antigravity "desaparecem" do sistema)
5. Ejeta `W:` via diskpart

Após o Stop, o PC age como uma máquina comum. Nenhum serviço de dev roda em background.

---

## 🔲 Sandbox — Ambiente Descartável

```
manage.bat → [4] SANDBOX
```

Use para tarefas arriscadas, testes práticos, ou projetos .NET Framework legados.

**O que você tem dentro:**
- VS Code (mapeado de `W:\Apps\VSCode` — sem instalar nada)
- Git (mapeado de `W:\Apps\Git` — sem instalar nada)
- Suas chaves SSH (de `C:\Users\<user>\.ssh`)
- Seus projetos legados (de `C:\Worker\projects_legacy`, **persistente**)

**O que some ao fechar:**
- Tudo que foi salvo no `C:\` dentro do Sandbox

---

## 🔑 Gestão de Túnel SSH/Bastion

Por segurança, o túnel SSH não sobe automaticamente.
- O `start-work.ps1` pergunta se deseja ativar ao iniciar.
- Para ligar manualmente depois: `wsl -d Ubuntu -- ssh -N bastion`

---

## ⚙️ Scripts Auxiliares

```powershell
# Otimiza o consumo de RAM do WSL (roda uma vez)
.\scripts\optimize-wsl.ps1

# Cria symlinks de pastas do Linux no Explorer do Windows
.\scripts\create-shortcuts.ps1

# Reset de emergência do WSL
.\scripts\reset-wsl.ps1
```

---

## 📋 Setup do Ubuntu (Primeira vez no WSL)

Após o provisionamento criar a distro, configure as ferramentas Linux:

```bash
# Dentro do Ubuntu (wsl -d Ubuntu)
cp /mnt/c/Worker/wsl/install-tools.sh ~/install-tools.sh
sed -i 's/\r$//' ~/install-tools.sh
chmod +x ~/install-tools.sh
sudo ./install-tools.sh
```

Isso instala: **NVM/Node**, **Kubectl**, **Git** (configurado), **alias set-dev** para DevContainers.

---

## 📐 Diagrama de Funcionamento

```
┌─────────────────────────────────────────────────────┐
│                   Windows Host (C:)                  │
│                                                      │
│  C:\Program Files\Git  ──symlink──► W:\Apps\Git     │
│  %LOCALAPPDATA%\VSCode ──symlink──► W:\Apps\VSCode  │
│  ~\.gemini\antigravity ──symlink──► W:\Apps\Antig.  │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │         W: Drive  (work-disk.vhdx)            │   │
│  │  Apps\ | DockerData\ | WSL\Ubuntu\ | Workspace│   │
│  └──────────────────────────────────────────────┘   │
│          │                                           │
│          ├── Docker Desktop (binário em C:)          │
│          │   └── Dados/Imagens em W:\DockerData      │
│          │                                           │
│          └── WSL2 Ubuntu (em W:\WSL\Ubuntu)          │
│              └── NVM, Kubectl, SSH, projetos         │
└─────────────────────────────────────────────────────┘
```

**Stop Work**: W: é ejetado → Symlinks removidos → PC volta ao estado "virgem".
