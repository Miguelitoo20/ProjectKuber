#!/bin/bash

# Función para verificar errores
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Verificar si estamos en WSL
if grep -qi microsoft /proc/version; then
    echo "Detectado entorno WSL"
    
    # Verificar Docker Desktop
    if ! command -v docker &> /dev/null; then
        echo "Docker no está instalado. Por favor, instala Docker Desktop para Windows y asegúrate de que WSL2 está habilitado."
        echo "1. Descarga Docker Desktop desde https://www.docker.com/products/docker-desktop"
        echo "2. Asegúrate de que WSL2 está configurado como backend en Docker Desktop"
        echo "3. Reinicia tu terminal WSL"
        exit 1
    else
        echo "Docker está instalado, verificando el servicio..."
        # En WSL con Docker Desktop, no necesitamos iniciar el servicio
        if ! docker info >/dev/null 2>&1; then
            echo "No se puede conectar a Docker. Por favor, verifica que Docker Desktop está ejecutándose en Windows"
            exit 1
        fi
        echo "Docker está funcionando correctamente"
    fi
else
    # Código original para sistemas no-WSL
    if ! command -v docker &> /dev/null; then
        echo "Docker no está instalado. Procediendo a instalar..."
        sudo apt-get remove docker docker-engine docker.io containerd runc -y
        sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y || check_error "No se pudieron instalar las dependencias de Docker."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/trusted.gpg.d/docker.asc || check_error "No se pudo agregar la llave GPG de Docker."
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || check_error "No se pudo agregar el repositorio de Docker."
        sudo apt-get update -y
        sudo apt-get install docker-ce docker-ce-cli containerd.io -y || check_error "No se pudo instalar Docker."
    fi

    # Configurar Docker para sistemas no-WSL
    if sudo systemctl start docker && sudo systemctl enable docker; then
        echo "Docker iniciado y habilitado correctamente."
    else
        echo "Failed to start Docker service. Ensure Docker is installed properly." >&2
        exit 1
    fi
fi

# Verificar e instalar Minikube
if ! command -v minikube &> /dev/null; then
    echo "Minikube no está instalado. Procediendo a instalar..."
    MINIKUBE_VERSION=$(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/${MINIKUBE_VERSION}/minikube-linux-amd64 || check_error "No se pudo descargar Minikube."
    chmod +x minikube
    sudo mv minikube /usr/local/bin/
else
    echo "Minikube ya está instalado."
fi

# Verificar e instalar kubectl
if ! command -v kubectl &> /dev/null; then
    echo "kubectl no está instalado. Procediendo a instalar..."
    KUBECTL_VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" || check_error "No se pudo descargar kubectl."
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
else
    echo "kubectl ya está instalado."
fi

# Iniciar Minikube con configuración optimizada
if ! minikube status &> /dev/null; then
    echo "Iniciando Minikube..."
    minikube start --driver=docker \
        --memory=2048 \
        --cpus=2 \
        --disk-size=20g || check_error "No se pudo iniciar Minikube."
else
    echo "Minikube ya está iniciado."
fi

# Resto del script continúa igual...
# Clonar el repositorio y aplicar configuraciones
if [ ! -d "Proyect-Kuber" ]; then
    echo "Clonando el repositorio..."
    git clone https://github.com/FranklinJunnior/Proyect-Kuber.git || check_error "No se pudo clonar el repositorio."
fi
cd Proyect-Kuber/kubernetes || check_error "No se pudo acceder al directorio kubernetes."

# Aplicar configuraciones de Kubernetes
echo "Aplicando configuraciones de Kubernetes..."
kubectl apply -f deployments/ || check_error "Error al aplicar deployments."
kubectl apply -f services/ || check_error "Error al aplicar services."
kubectl apply -f monitoring/ || check_error "Error al aplicar monitoring."

# Mostrar URLs de acceso
echo "URLs de acceso:"
for service in "grafana" "prometheus" "vote-app"; do
    URL=$(minikube service $service --url)
    echo "$service está disponible en: $URL"
done

# Guardar información importante
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