#!/usr/bin/env bash

clear
echo "======================================"
echo " ESTADO DEL STACK IBDN"
echo "======================================"
echo ""

echo "CONTENEDORES:"
docker  ps

echo ""
echo "REINICIOS:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

echo ""
echo "--------------------------------------"
echo "FLAGS DE INICIALIZACIÓN"
echo "--------------------------------------"

check_file () {
  if [ -f "$1" ]; then
    echo "OK  $1"
  else
    echo "NO  $1"
  fi
}

check_file ".cassandra_ready"
check_file ".iceberg_ready"
check_file ".models_lakehouse_ready"

echo ""
echo "--------------------------------------"
echo "SERVICIOS WEB"
echo "--------------------------------------"
echo "Spark Master: http://localhost:8081"
echo "Airflow:      http://localhost:8080"
echo "MLflow:       http://localhost:5000"
echo "MinIO:        http://localhost:9001"
echo "Flask Web:    http://localhost:5001"

echo ""
echo "--------------------------------------"
echo "ÚLTIMOS LOGS IMPORTANTES"
echo "--------------------------------------"
echo ""
echo "[kafka-init]"
docker logs kafka-init --tail 5 2>/dev/null || true

echo ""
echo "[cassandra-init]"
docker logs cassandra-init --tail 5 2>/dev/null || true

echo ""
echo "[lakehouse-init]"
docker logs lakehouse-init --tail 5 2>/dev/null || true

echo ""
echo "[airflow]"
docker logs airflow --tail 5 2>/dev/null || true

echo ""
echo "[spark-predictor]"
docker logs spark-predictor --tail 5 2>/dev/null || true

echo ""
echo "[flask-web]"
docker logs flask-web --tail 5 2>/dev/null || true
