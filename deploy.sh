#!/bin/bash

# Función para verificar errores
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Función para verificar permisos de Docker
verify_docker_permissions() {
    # Intentar ejecutar docker sin sudo
    if docker info >/dev/null 2>&1; then
        echo "Permisos de Docker verificados correctamente"
        return 0
    else
        return 1
    fi
}

# Verificar sistema operativo
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Este script está diseñado para Ubuntu. Por favor, usa una AMI de Ubuntu."
    exit 1
fi

# Verificar recursos mínimos
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
AVAILABLE_DISK=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')

if [ $CPU_CORES -lt 2 ] || [ $TOTAL_MEM -lt 2048 ]; then
    echo "Recursos insuficientes. Se requieren mínimo:"
    echo "- 2 CPU cores (actual: $CPU_CORES)"
    echo "- 2GB RAM (actual: $TOTAL_MEM MB)"
    exit 1
fi

if [ $AVAILABLE_DISK -lt 20 ]; then
    echo "Se requieren al menos 20GB de espacio disponible"
    exit 1
fi

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt-get update -y || check_error "No se pudo actualizar el sistema"
sudo apt-get upgrade -y || check_error "No se pudo actualizar los paquetes"

# Instalar Docker con verificación
echo "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    # Eliminar versiones antiguas
    sudo apt-get remove docker docker-engine docker.io containerd runc -y

    # Instalar dependencias
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y || check_error "No se pudieron instalar las dependencias"

    # Añadir repositorio Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/trusted.gpg.d/docker.asc
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update -y

    # Instalar Docker
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y || check_error "No se pudo instalar Docker"
else
    echo "Docker ya está instalado"
fi

# Configurar Docker
sudo systemctl start docker || check_error "No se pudo iniciar Docker"
sudo systemctl enable docker

# Configurar permisos de Docker
echo "Configurando permisos de Docker..."
if ! verify_docker_permissions; then
    # Añadir usuario al grupo docker
    sudo usermod -aG docker $USER
    
    # Crear el socket de Docker con los permisos correctos
    sudo chmod 666 /var/run/docker.sock
    
    # Reiniciar el servicio de Docker
    sudo systemctl restart docker
    
    echo "Esperando a que Docker esté disponible..."
    sleep 5
    
    # Verificar nuevamente los permisos
    if ! verify_docker_permissions; then
        echo "Error: No se pudieron establecer los permisos de Docker correctamente."
        echo "Por favor, ejecuta los siguientes comandos manualmente y luego vuelve a ejecutar el script:"
        echo "1. sudo usermod -aG docker \$USER"
        echo "2. newgrp docker"
        exit 1
    fi
fi

# Instalar la última versión de Minikube
echo "Instalando Minikube..."
MINIKUBE_VERSION=$(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -Lo minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64 || check_error "No se pudo descargar Minikube"
chmod +x minikube
sudo mv minikube /usr/local/bin/

# Instalar kubectl
echo "Instalando kubectl..."
KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" || check_error "No se pudo descargar kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verificar permisos de Docker antes de iniciar Minikube
if ! verify_docker_permissions; then
    echo "Error: No tienes permisos para ejecutar Docker sin sudo."
    echo "Por favor, cierra la sesión y vuelve a iniciar sesión, luego ejecuta el script nuevamente."
    exit 1
fi

# Iniciar Minikube con configuración optimizada para EC2
echo "Iniciando Minikube..."
minikube start --driver=docker \
    --memory=2048 \
    --cpus=2 \
    --disk-size=20g || check_error "No se pudo iniciar Minikube"

# Verificar la instalación
echo "Verificando la instalación..."
kubectl cluster-info || check_error "No se pudo verificar el cluster"

# Clonar el repositorio y aplicar configuraciones
echo "Clonando el repositorio..."
git clone https://github.com/FranklinJunnior/Proyect-Kuber.git || check_error "No se pudo clonar el repositorio"
cd Proyect-Kuber/kubernetes || check_error "No se pudo acceder al directorio kubernetes"

# Aplicar configuraciones con verificación
echo "Aplicando configuraciones de Kubernetes..."
kubectl apply -f deployments/ || check_error "Error al aplicar deployments"
kubectl apply -f services/ || check_error "Error al aplicar services"
kubectl apply -f monitoring/ || check_error "Error al aplicar monitoring"

# Exponer servicios con verificación de estado
echo "Exponiendo servicios..."
for service in "vote-app:80" "grafana:3000" "prometheus:9090"; do
    NAME=$(echo $service | cut -d: -f1)
    PORT=$(echo $service | cut -d: -f2)
    kubectl expose deployment $NAME --type=NodePort --port=$PORT --target-port=$PORT --name=$NAME-service || check_error "No se pudo exponer el servicio $NAME"
done

# Mostrar URLs de acceso
echo "URLs de acceso:"
for service in "grafana" "prometheus" "vote-app"; do
    URL=$(minikube service $service --url)
    echo "$service está disponible en: $URL"
done

# Guardar información importante en un archivo
echo "Guardando información de la instalación..."
cat > installation_info.txt << EOF
Fecha de instalación: $(date)
Versión de Minikube: $(minikube version)
Versión de kubectl: $(kubectl version --client)
Versión de Docker: $(docker --version)

URLs de acceso:
$(kubectl get svc -o wide)
EOF

echo "Instalación completada. Revise installation_info.txt para más detalles."
