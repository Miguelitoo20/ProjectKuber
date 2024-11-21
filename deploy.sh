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
        exit 1
    else
        echo "Docker está instalado, verificando el servicio..."
        
        # Fix para WSL: Asegurarse de que el socket de Docker existe y tiene los permisos correctos
        if [ ! -S /var/run/docker.sock ]; then
            echo "Creando enlace al socket de Docker..."
            DOCKER_DISTRO="Ubuntu"
            DOCKER_DIR=/mnt/wsl/shared-docker
            DOCKER_SOCK="$DOCKER_DIR/docker.sock"
            
            if [ ! -d $DOCKER_DIR ]; then
                sudo mkdir -pm o=,ug=rwx "$DOCKER_DIR"
            fi
            
            if [ ! -S $DOCKER_SOCK ]; then
                echo "Esperando que Docker Desktop inicie..."
                sleep 10
            fi
            
            if [ ! -S $DOCKER_SOCK ]; then
                echo "No se puede encontrar el socket de Docker. Por favor:"
                echo "1. Abre Docker Desktop"
                echo "2. Ve a Settings -> Resources -> WSL Integration"
                echo "3. Asegúrate de que la integración está habilitada para Ubuntu"
                echo "4. Reinicia Docker Desktop"
                exit 1
            fi
        fi
        
        # Intentar conectar con Docker
        if ! docker info >/dev/null 2>&1; then
            echo "Intentando fix adicional para Docker..."
            export DOCKER_HOST=tcp://localhost:2375
            if ! docker info >/dev/null 2>&1; then
                echo "No se puede conectar a Docker. Por favor:"
                echo "1. Verifica que Docker Desktop está ejecutándose"
                echo "2. En Docker Desktop, ve a Settings -> General y marca 'Expose daemon on tcp://localhost:2375 without TLS'"
                echo "3. Reinicia Docker Desktop"
                exit 1
            fi
        fi
        echo "Docker está funcionando correctamente"
    fi
fi

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

# Actualizar el sistema
echo "Actualizando el sistema..."
sudo apt-get update -y || check_error "No se pudo actualizar el sistema."
sudo apt-get upgrade -y || check_error "No se pudo actualizar los paquetes."

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

# Clonar el repositorio y aplicar configuraciones
if [ ! -d "Proyect-Kuber" ]; then
    echo "Clonando el repositorio..."
    git clone https://github.com/Miguelitoo20/ProjectKuber.git || check_error "No se pudo clonar el repositorio."
fi

cd ProjectKuber/Proyect-Kuber/kubernetes || check_error "No se pudo acceder al directorio kubernetes."

# Verificar si los directorios existen antes de aplicar configuraciones
if [ -d "deployments" ] && [ -d "services" ] && [ -d "monitoring" ]; then
    # Aplicar configuraciones de Kubernetes
    echo "Aplicando configuraciones de Kubernetes..."
    kubectl apply -f deployments/ || check_error "Error al aplicar deployments."
    kubectl apply -f services/ || check_error "Error al aplicar services."
    kubectl apply -f monitoring/ || check_error "Error al aplicar monitoring."

    # Esperar a que los servicios estén listos
    echo "Esperando a que los servicios estén listos..."
    kubectl wait --for=condition=ready pod -l app=grafana --timeout=300s
    kubectl wait --for=condition=ready pod -l app=prometheus --timeout=300s
    kubectl wait --for=condition=ready pod -l app=vote-app --timeout=300s

    # Mostrar URLs de acceso
    echo "URLs de acceso:"
    for service in "grafana" "prometheus" "vote-app"; do
        URL=$(minikube service $service --url)
        echo "$service está disponible en: $URL"
    done
else
    echo "Error: No se encontraron los directorios necesarios en el repositorio."
    echo "Estructura esperada:"
    echo "- deployments/"
    echo "- services/"
    echo "- monitoring/"
    exit 1
fi

# Guardar información importante
echo "Guardando información de la instalación..."
cat > installation_info.txt << EOF
Fecha de instalación: $(date)
Versión de Minikube: $(minikube version)
Versión de kubectl: $(kubectl version --client)
Versión de Docker: $(docker --version)

URLs de acceso:
$(kubectl get svc -o wide)

Estado de los pods:
$(kubectl get pods -o wide)

Notas adicionales:
- Para acceder a los servicios, use los URLs proporcionados arriba
- Para detener minikube: minikube stop
- Para iniciar minikube: minikube start
EOF

echo "Instalación completada. Revise installation_info.txt para más detalles."
echo "
Instrucciones post-instalación:
1. Para acceder a los servicios, use los URLs mostrados arriba
2. Para detener el cluster: minikube stop
3. Para iniciar el cluster: minikube start
4. Para eliminar el cluster: minikube delete
"