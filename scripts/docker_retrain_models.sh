#!/usr/bin/env bash

set -e

DAG_ID="agile_data_science_batch_prediction_model_training"
READY_FILE="resources/airflow/.models_lakehouse_ready"

echo "======================================"
echo " REENTRENANDO MODELO CON AIRFLOW"
echo "======================================"

echo ""
echo "Eliminando marca de modelos entrenados..."
rm -f "$READY_FILE"

echo ""
echo "Comprobando que Airflow responde..."
docker exec airflow airflow dags list | grep -q "$DAG_ID" \
  && echo "✅ DAG encontrado: $DAG_ID" \
  || { echo "❌ No se encontró el DAG $DAG_ID"; exit 1; }

echo ""
echo "Lanzando DAG..."
docker exec airflow airflow dags trigger "$DAG_ID"

echo ""
echo "Esperando a que se genere $READY_FILE..."

START_TIME=$(date +%s)

while true; do
  if [ -f "$READY_FILE" ]; then
    echo "✅ Modelos reentrenados correctamente"
    break
  fi

  LAST_RUN_STATE=$(docker exec airflow airflow dags list-runs -d "$DAG_ID" --no-backfill 2>/dev/null | awk 'NR==3 {print $NF}' || echo "unknown")

  if echo "$LAST_RUN_STATE" | grep -qi "failed"; then
    echo ""
    echo "❌ El DAG ha fallado"
    echo ""
    echo "Últimos logs de Airflow:"
    docker logs airflow --tail 120
    exit 1
  fi

  NOW=$(date +%s)
  echo "⏳ [$((NOW - START_TIME))s] Entrenamiento en curso..."
  sleep 15
done

echo ""
echo "Comprobando MLflow..."
curl -s http://localhost:5000 >/dev/null \
  && echo "✅ MLflow disponible en http://localhost:5000" \
  || echo "⚠️ No se pudo comprobar MLflow desde localhost"

echo ""
echo "======================================"
echo " ✅ REENTRENAMIENTO FINALIZADO"
echo "======================================"
echo ""
echo "Abre MLflow:"
echo "http://localhost:5000"
echo ""
echo "Busca el experimento:"
echo "flight-delay-training"
