#!/usr/bin/env bash
set -e

echo "======================================"
echo " ARRANCANDO STACK KUBERNETES IBDN"
echo "======================================"

minikube status >/dev/null 2>&1 || minikube start

eval $(minikube docker-env)

./scripts/download_dependencies.sh

if [ ! -f flight_prediction/target/scala-2.13/flight_prediction_2.13-0.1.jar ]; then
    echo "JAR no encontrado. Compilando..."
    cd flight_prediction
    sbt package
    cd ..
else
    echo "JAR ya compilado."
fi

echo "Construyendo imágenes..."
docker build -t practica-spark:latest -f Dockerfile.spark .
docker build -t practica-web:latest -f Dockerfile.web .
docker build -t practica-airflow:latest -f Dockerfile.airflow .

echo "Desplegando en Kubernetes..."
./scripts/k8s_deploy.sh

echo "Comprobando despliegue..."
./scripts/k8s_check.sh
