#!/usr/bin/env bash

set -u

START_TIME=$(date +%s)

elapsed() {
  NOW=$(date +%s)
  echo "$((NOW - START_TIME))"
}

ok() { echo "✅ $1"; }
wait_msg() { echo "⏳ $1"; }
fail() { echo "❌ $1"; exit 1; }

wait_container_running() {
  NAME=$1

  while true; do
    STATUS=$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo "missing")

    if [ "$STATUS" = "running" ]; then
      ok "$NAME running"
      break
    fi

    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
      echo ""
      echo "Logs de $NAME:"
      docker logs "$NAME" --tail 80 2>/dev/null || true
      fail "$NAME ha terminado con error"
    fi

    wait_msg "[$(elapsed)s] $NAME todavía no está running..."
    sleep 5
  done
}

wait_container_healthy() {
  NAME=$1

  while true; do
    HEALTH=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$NAME" 2>/dev/null || echo "missing")
    STATUS=$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo "missing")

    if [ "$HEALTH" = "healthy" ]; then
      ok "$NAME healthy"
      break
    fi

    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
      echo ""
      echo "Logs de $NAME:"
      docker logs "$NAME" --tail 80 2>/dev/null || true
      fail "$NAME ha terminado con error"
    fi

    wait_msg "[$(elapsed)s] $NAME todavía no está healthy ($HEALTH)..."
    sleep 5
  done
}

wait_container_exited_ok() {
  NAME=$1

  while true; do
    STATUS=$(docker inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null || echo "missing")
    EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' "$NAME" 2>/dev/null || echo "999")

    if [ "$STATUS" = "exited" ] && [ "$EXIT_CODE" = "0" ]; then
      ok "$NAME terminado correctamente"
      break
    fi

    if [ "$STATUS" = "exited" ] && [ "$EXIT_CODE" != "0" ]; then
      echo ""
      echo "Logs de $NAME:"
      docker logs "$NAME" --tail 100 2>/dev/null || true
      fail "$NAME terminó con código $EXIT_CODE"
    fi

    wait_msg "[$(elapsed)s] $NAME todavía ejecutándose..."
    sleep 5
  done
}

wait_file() {
  FILE=$1

  while true; do
    if [ -f "$FILE" ]; then
      ok "$FILE existe"
      break
    fi

    wait_msg "[$(elapsed)s] Esperando $FILE..."
    sleep 5
  done
}

wait_models_ready() {
  FILE=".models_lakehouse_ready"
  DAG_ID="agile_data_science_batch_prediction_model_training"

  while true; do
    if [ -f "$FILE" ]; then
      ok "$FILE existe"
      break
    fi

    LAST_RUN_STATE=$(docker exec airflow airflow dags list-runs -d "$DAG_ID" --no-backfill 2>/dev/null | awk 'NR==3 {print $NF}' || echo "unknown")

    if echo "$LAST_RUN_STATE" | grep -qi "failed"; then
      echo ""
      echo "Logs de Airflow:"
      docker logs airflow --tail 120
      fail "El DAG de entrenamiento ha fallado"
    fi

    if echo "$LAST_RUN_STATE" | grep -qi "success"; then
      fail "El DAG aparece como success pero no se ha creado $FILE"
    fi

    wait_msg "[$(elapsed)s] Entrenamiento todavía en curso. Esperando $FILE..."
    sleep 10
  done
}

wait_kafka_ready() {
  echo "Comprobando Kafka..."

  while true; do
    STATUS=$(docker inspect -f '{{.State.Status}}' kafka 2>/dev/null || echo "missing")

    if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
      echo ""
      echo "Logs de kafka:"
      docker logs kafka --tail 100 2>/dev/null || true
      fail "kafka ha terminado con error"
    fi

    if docker exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --list >/dev/null 2>&1; then
      ok "kafka responde correctamente"
      break
    fi

    wait_msg "[$(elapsed)s] kafka todavía no responde..."
    sleep 5
  done
}

echo ""
echo "======================================"
echo " ESPERANDO STACK IBDN"
echo "======================================"
echo ""

wait_container_healthy cassandra
wait_kafka_ready
wait_container_healthy minio
wait_container_healthy mlflow

wait_container_exited_ok kafka-init
wait_container_exited_ok minio-init
wait_container_exited_ok cassandra-init
wait_container_exited_ok lakehouse-init

wait_file ".cassandra_ready"
wait_file ".iceberg_ready"
wait_models_ready

wait_container_running spark-master
wait_container_running spark-worker-1
wait_container_running spark-worker-2
wait_container_running airflow
wait_container_running spark-predictor
wait_container_healthy flask-web

echo ""
echo "Comprobando Spark Streaming en cluster..."

while true; do
  STATUS=$(docker inspect -f '{{.State.Status}}' spark-predictor 2>/dev/null || echo "missing")

  if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
    echo ""
    echo "Logs de spark-predictor:"
    docker logs spark-predictor --tail 120 2>/dev/null || true
    fail "spark-predictor ha terminado con error"
  fi

  SPARK_JSON=$(docker exec spark-predictor sh -c "curl -s http://spark-master:8081/json/" 2>/dev/null || true)

  if echo "$SPARK_JSON" | grep -q "FlightDelayStreamingPrediction"; then
    ok "FlightDelayStreamingPrediction aparece en Spark Master"
    break
  fi

  wait_msg "[$(elapsed)s] FlightDelayStreamingPrediction todavía no aparece en Spark Master..."
  docker logs spark-predictor --tail 5 2>/dev/null || true
  sleep 5
done

CORES_USED=$(echo "$SPARK_JSON" | grep -o '"coresused" : [0-9]*' | head -n 1 | grep -o '[0-9]*')

if [ "${CORES_USED:-0}" -gt 0 ]; then
  ok "Spark está usando ${CORES_USED} cores del cluster"
else
  fail "Spark no está usando recursos del cluster"
fi

echo ""
echo "======================================"
echo " ✅ STACK LISTO"
echo "======================================"
echo ""
echo "Tiempo total: $(elapsed) segundos"
echo ""
echo "Spark:   http://localhost:8081"
echo "Airflow: http://localhost:8080"
echo "MLflow:  http://localhost:5000"
echo "MinIO:   http://localhost:9001"
echo "Flask:   http://localhost:5001"
echo ""