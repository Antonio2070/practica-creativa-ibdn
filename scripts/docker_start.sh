#!/usr/bin/env bash
set -e

echo "======================================"
echo " ARRANCANDO STACK DOCKER IBDN"
echo "======================================"

docker-compose up -d --build

echo ""
echo "Esperando a que el stack esté listo..."
./scripts/wait_stack_ready.sh

