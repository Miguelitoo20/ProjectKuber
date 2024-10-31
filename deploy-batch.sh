#!/bin/bash
# deploy.sh

echo "🚀 Iniciando despliegue..."

# Clonar el repositorio
git clone https://github.com/JancoF/examenig && cd exam

# Desplegar con docker-compose
docker-compose up -d

echo " Proyecto desplegado!"