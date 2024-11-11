#!/bin/bash

# Verificar si kubectl está instalado
if ! command -v kubectl &> /dev/null
then
    echo "kubectl no está instalado. Por favor, instálalo y vuelve a intentarlo."
    exit 1
fi

# Paso 1: Clonar el repositorio
echo "Clonando el repositorio..."
git clone https://github.com/FranklinJunnior/Proyect-Kuber.git

# Verificar si el git clone fue exitoso
if [ $? -ne 0 ]; then
    echo "Error al clonar el repositorio."
    exit 1
fi

# Paso 2: Verificar si la carpeta kubernetes existe y cambiar al directorio del repositorio clonado
if [ ! -d "Proyect-Kuber/kubernetes" ]; then
    echo "El directorio kubernetes no existe. Verifica la estructura del repositorio."
    exit 1
fi
cd Proyect-Kuber/kubernetes

# Paso 3: Aplicar los archivos de Kubernetes
echo "Aplicando los archivos de Kubernetes..."

# Crear los deployments y servicios para las aplicaciones, incluyendo la exposición de puertos.
kubectl apply -f deployments/
kubectl apply -f services/
kubectl apply -f monitoring/

# Paso 4: Verificar el estado de los pods en Kubernetes
echo "Verificando el estado de los pods..."
kubectl get pods

# Exponer los servicios en los puertos especificados
echo "Exponiendo los puertos importantes..."
kubectl expose deployment vote-app --type=NodePort --port=80 --target-port=80 --name=vote-app-service
kubectl expose deployment grafana --type=NodePort --port=3000 --target-port=3000 --name=grafana-service
kubectl expose deployment prometheus --type=NodePort --port=9090 --target-port=9090 --name=prometheus-service

echo "Puertos expuestos correctamente."

# Verificar los servicios expuestos
echo "Verificando los servicios expuestos..."
kubectl get svc
