#!/bin/bash

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

# -----------------------------
# Update package index
# -----------------------------
echo -e "${BLUE}🔄 Updating package index...${RESET}"
sudo apt update -y
sudo apt install -y curl ca-certificates gnupg lsb-release software-properties-common

# -----------------------------
# Install Docker
# -----------------------------
echo -e "${BLUE}➡️ Installing Docker...${RESET}"
curl -fsSL https://get.docker.com | sh
echo -e "${GREEN}✅ Docker installed. Version:${RESET}"
docker --version

# -----------------------------
# Install Docker Compose
# -----------------------------
echo -e "${BLUE}➡️ Installing Docker Compose...${RESET}"
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo -e "${GREEN}✅ Docker Compose installed. Version:${RESET}"
docker-compose --version || docker compose version
