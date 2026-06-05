#!/usr/bin/env bash
set -e

echo "======================================"
echo " ARRANCANDO STACK DOCKER IBDN"
echo "======================================"

./scripts/download_dependencies.sh

if [ ! -f flight_prediction/target/scala-2.13/flight_prediction_2.13-0.1.jar ]; then
    echo "JAR no encontrado. Compilando..."
    cd flight_prediction
    sbt package
    cd ..
else
    echo "JAR ya compilado."
fi

docker-compose up -d --build

echo ""
echo "Esperando a que el stack esté listo..."
./scripts/wait_stack_ready.sh

