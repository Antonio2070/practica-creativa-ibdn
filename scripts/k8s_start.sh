#!/usr/bin/env bash
set -e

echo "======================================"
echo " ARRANCANDO STACK KUBERNETES IBDN"
echo "======================================"

minikube status >/dev/null 2>&1 || minikube start

eval $(minikube docker-env)

echo "Construyendo imágenes..."
docker build -t practica-spark:latest -f Dockerfile.spark .
docker build -t practica-web:latest -f Dockerfile.web .
docker build -t practica-airflow:latest -f Dockerfile.airflow .

echo "Desplegando en Kubernetes..."
./scripts/k8s_deploy.sh

echo "Comprobando despliegue..."
./scripts/k8s_check.sh
