#!/usr/bin/env bash

set -e

NS="practica-ibdn"

ok() { echo "✅ $1"; }
fail() { echo "❌ $1"; exit 1; }

echo "======================================"
echo " COMPROBANDO STACK KUBERNETES IBDN"
echo "======================================"
echo ""

echo "Comprobando pods..."
kubectl get pods -n "$NS"

for APP in cassandra kafka minio mlflow spark-master spark-worker spark-predictor flask-web; do
  READY=$(kubectl get pods -n "$NS" -l app="$APP" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{" "}{end}' 2>/dev/null || true)

  if echo "$READY" | grep -q "true"; then
    ok "$APP ready"
  else
    fail "$APP no está ready"
  fi
done

echo ""
echo "Comprobando Kafka..."
kubectl exec -n "$NS" deploy/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:29092 \
  --list | grep -q "flight-delay-ml-request" \
  && ok "topic flight-delay-ml-request existe" \
  || fail "topic flight-delay-ml-request no existe"

kubectl exec -n "$NS" deploy/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:29092 \
  --list | grep -q "flight-delay-ml-response" \
  && ok "topic flight-delay-ml-response existe" \
  || fail "topic flight-delay-ml-response no existe"

echo ""
echo "Comprobando Cassandra..."
DISTANCES=$(kubectl exec -n "$NS" deploy/cassandra -- cqlsh -e "SELECT COUNT(*) FROM agile_data_science.origin_dest_distances;" | grep -E '^[[:space:]]*[0-9]+' | tr -d ' ')

if [ "${DISTANCES:-0}" -gt 0 ]; then
  ok "origin_dest_distances tiene $DISTANCES filas"
else
  fail "origin_dest_distances está vacía o no existe"
fi

PREDICTIONS=$(kubectl exec -n "$NS" deploy/cassandra -- cqlsh -e "SELECT COUNT(*) FROM agile_data_science.flight_delay_ml_response;" | grep -E '^[[:space:]]*[0-9]+' | tr -d ' ')

ok "flight_delay_ml_response tiene ${PREDICTIONS:-0} filas"

echo ""
echo "Comprobando MinIO..."
MINIO_BUCKETS=$(kubectl run minio-check -n "$NS" --rm -i \
  --image=minio/mc:latest \
  --restart=Never \
  --command -- sh -c "mc alias set local http://minio:9000 admin password123 >/dev/null && mc ls local" 2>/dev/null || true)

echo "$MINIO_BUCKETS" | grep -q "warehouse" \
  && ok "bucket warehouse existe" \
  || fail "bucket warehouse no existe"
  
echo ""
echo "Comprobando Spark Master..."
SPARK_JSON=$(kubectl exec -n "$NS" deploy/spark-predictor -- curl -s http://spark-master:8081/json/)

echo "$SPARK_JSON" | grep -q '"aliveworkers" : 2' \
  && ok "Spark tiene 2 workers vivos" \
  || fail "Spark no tiene 2 workers vivos"

echo "$SPARK_JSON" | grep -q "FlightDelayStreamingPrediction" \
  && ok "FlightDelayStreamingPrediction está registrada" \
  || fail "FlightDelayStreamingPrediction no aparece en Spark"

echo ""
echo "Comprobando MLflow..."
kubectl exec -n "$NS" deploy/mlflow -- sh -c "python - <<'PY'
import urllib.request
urllib.request.urlopen('http://localhost:5000', timeout=5)
print('MLflow OK')
PY" >/dev/null \
  && ok "MLflow responde" \
  || fail "MLflow no responde"

echo ""
echo "Comprobando Flask..."
FLASK_URL=$(minikube service flask-web -n "$NS" --url 2>/dev/null | head -n 1)

if [ -n "$FLASK_URL" ]; then
  ok "Flask expuesto en $FLASK_URL"
else
  fail "No se pudo obtener URL de Flask"
fi

echo ""
echo "======================================"
echo " ✅ STACK KUBERNETES OK"
echo "======================================"
echo ""
echo "Flask:   $FLASK_URL"
echo "Spark:   kubectl port-forward -n $NS svc/spark-master 8081:8081"
echo "MLflow:  kubectl port-forward -n $NS svc/mlflow 5000:5000"
echo ""
