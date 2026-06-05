#!/usr/bin/env bash
set -e

echo "======================================"
echo " PARANDO STACK KUBERNETES IBDN"
echo "======================================"

kubectl delete namespace practica-ibdn --ignore-not-found

echo "Namespace practica-ibdn eliminado."
echo ""
echo "Si quieres parar Minikube completamente:"
echo "minikube stop"

