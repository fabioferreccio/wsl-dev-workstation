#!/bin/bash
# install-tools.sh — Setup do ambiente Ubuntu (WSL)
# Executado uma vez após o provisionamento ou migração.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}   WSL UBUNTU: Setup de Ferramentas${NC}"
echo -e "${CYAN}============================================================${NC}"

# 0. Dependências essenciais
echo -e "\n${YELLOW}[1/5] Instalando dependencias de sistema...${NC}"
sudo apt-get update -qq && sudo apt-get install -y -qq \
    curl git gnupg2 ca-certificates apt-transport-https unzip

# 1. NVM (Node Version Manager)
echo -e "\n${YELLOW}[2/5] Verificando NVM...${NC}"
export NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    echo -e "${GREEN}✔ NVM ja instalado.${NC}"
else
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# Garantir linhas no .bashrc
if ! grep -q "NVM_DIR" ~/.bashrc; then
    echo 'export NVM_DIR="$HOME/.nvm"'                         >> ~/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'   >> ~/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
fi

# Carregar NVM na sessão atual
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
command -v nvm > /dev/null 2>&1 \
    && echo -e "${GREEN}✔ NVM ativo.${NC}" \
    || echo -e "${RED}✘ NVM requer 'source ~/.bashrc'.${NC}"

# 2. Kubectl
echo -e "\n${YELLOW}[3/5] Verificando Kubectl...${NC}"
if command -v kubectl > /dev/null 2>&1; then
    echo -e "${GREEN}✔ Kubectl ja instalado.${NC}"
else
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y kubectl
    echo -e "${GREEN}✔ Kubectl instalado.${NC}"
fi

# 3. DevContainer Global (link para C:\Worker\containers)
echo -e "\n${YELLOW}[4/5] Configurando DevContainer Global...${NC}"
GLOBAL_CFG="/mnt/c/Worker/containers/generic-dev-env"
if [ -L "$HOME/.global-devcontainer" ]; then
    echo -e "${GREEN}✔ Link .global-devcontainer ja existe.${NC}"
elif [ -d "$GLOBAL_CFG" ]; then
    ln -sfn "$GLOBAL_CFG" ~/.global-devcontainer
    echo -e "${GREEN}✔ Link .global-devcontainer criado.${NC}"
else
    echo -e "${YELLOW}⚠ Pasta generic-dev-env nao encontrada em C:\Worker.${NC}"
fi

# Alias set-dev
if ! grep -q "alias set-dev=" ~/.bashrc; then
    echo "alias set-dev='ln -sfn ~/.global-devcontainer .devcontainer'" >> ~/.bashrc
    echo -e "${GREEN}✔ Alias 'set-dev' adicionado.${NC}"
fi

# 4. Configuração do Git
echo -e "\n${YELLOW}[5/5] Configurando Git...${NC}"
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

read -p "Nome para Git [${CURRENT_NAME:-Seu Nome}]: " GIT_NAME
GIT_NAME=${GIT_NAME:-$CURRENT_NAME}

read -p "E-mail para Git [${CURRENT_EMAIL:-seu@email.com}]: " GIT_EMAIL
GIT_EMAIL=${GIT_EMAIL:-$CURRENT_EMAIL}

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global core.filemode false
# NUNCA modificar line endings — compatibilidade Windows/WSL
git config --global core.autocrlf false

echo -e "${GREEN}✔ Git configurado: $GIT_NAME <$GIT_EMAIL>${NC}"

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}   SETUP WSL CONCLUIDO!${NC}"
echo -e "${CYAN}============================================================${NC}"
echo -e " Rode ${YELLOW}source ~/.bashrc${NC} para ativar NVM e aliases."
echo ""