#!/bin/bash

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Paso 1: Instalar Docker
echo "Instalando Docker..."

# Eliminar versiones antiguas
sudo apt-get remove docker docker-engine docker.io containerd runc -y

# Instalar dependencias necesarias
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y

# Añadir la clave GPG oficial de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/trusted.gpg.d/docker.asc

# Añadir el repositorio de Docker a APT
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Actualizar el índice de paquetes APT
sudo apt-get update -y

# Instalar Docker
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

# Verificar que Docker se instaló correctamente
sudo systemctl start docker
sudo systemctl enable docker
sudo docker --version

# Agregar al usuario actual al grupo de Docker (esto permite ejecutar Docker sin sudo)
if ! groups $USER | grep -q "\bdocker\b"; then
    echo "Agregando el usuario al grupo Docker..."
    sudo usermod -aG docker $USER
    echo "Es necesario reiniciar sesión o ejecutar 'newgrp docker' para que los cambios de grupo tengan efecto."
    newgrp docker
else
    echo "El usuario ya está en el grupo Docker."
fi

# Paso 2: Verificar acceso a Docker
echo "Verificando acceso a Docker sin sudo..."
docker info

# Paso 3: Instalar Minikube
echo "Instalando Minikube..."

# Descargar la última versión de Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/v1.30.0/minikube-linux-amd64

# Dar permisos de ejecución y mover a /usr/local/bin
chmod +x minikube
sudo mv minikube /usr/local/bin/

# Verificar instalación de Minikube
minikube version

# Paso 4: Instalar kubectl
echo "Instalando kubectl..."

# Descargar la última versión de kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"

# Dar permisos de ejecución y mover a /usr/local/bin
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Verificar instalación de kubectl
kubectl version --client

# Paso 5: Verificar que Docker esté en funcionamiento antes de iniciar Minikube
if ! systemctl is-active --quiet docker; then
    echo "Docker no está corriendo. Inicia Docker antes de continuar."
    exit 1
fi

# Paso 6: Iniciar Minikube
echo "Iniciando Minikube..."
minikube start --driver=docker

# Verificar que Minikube esté funcionando correctamente
minikube status
if [ $? -ne 0 ]; then
    echo "Minikube no pudo iniciarse correctamente. Por favor, verifica los logs."
    exit 1
fi

# Paso 7: Verificar el acceso al clúster de Minikube
echo "Verificando el acceso al clúster de Minikube..."
kubectl cluster-info

# Paso 8: Clonar el repositorio
echo "Clonando el repositorio..."
git clone https://github.com/FranklinJunnior/Proyect-Kuber.git

# Verificar si el git clone fue exitoso
if [ $? -ne 0 ]; then
    echo "Error al clonar el repositorio."
    exit 1
fi

# Paso 9: Verificar si la carpeta kubernetes existe y cambiar al directorio del repositorio clonado
if [ ! -d "Proyect-Kuber/kubernetes" ]; then
    echo "El directorio kubernetes no existe. Verifica la estructura del repositorio."
    exit 1
fi
cd Proyect-Kuber/kubernetes

# Paso 10: Aplicar los archivos de Kubernetes
echo "Aplicando los archivos de Kubernetes..."
kubectl apply -f deployments/
kubectl apply -f services/
kubectl apply -f monitoring/

# Paso 11: Verificar el estado de los pods en Kubernetes
echo "Verificando el estado de los pods..."
kubectl get pods

# Paso 12: Exponer los servicios en los puertos especificados
echo "Exponiendo los puertos importantes..."
kubectl expose deployment vote-app --type=NodePort --port=80 --target-port=80 --name=vote-app-service
kubectl expose deployment grafana --type=NodePort --port=3000 --target-port=3000 --name=grafana-service
kubectl expose deployment prometheus --type=NodePort --port=9090 --target-port=9090 --name=prometheus-service

echo "Puertos expuestos correctamente."

# Paso 13: Verificar los servicios expuestos
echo "Verificando los servicios expuestos..."
kubectl get svc

# Paso 14: Verificar el acceso a los servicios expuestos
# Obtener la URL de Grafana
GRAFANA_URL=$(minikube service grafana --url)
echo "Grafana está disponible en la URL: $GRAFANA_URL"

# Obtener la URL de Prometheus
PROMETHEUS_URL=$(minikube service prometheus --url)
echo "Prometheus está disponible en la URL: $PROMETHEUS_URL"

# Obtener la URL de la aplicación Vote
VOTE_APP_URL=$(minikube service vote-app --url)
echo "La aplicación Vote está disponible en la URL: $VOTE_APP_URL"

# Fin del script
echo "Proceso de instalación y configuración completado."
