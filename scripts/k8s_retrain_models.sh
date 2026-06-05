#!/usr/bin/env bash

set -e

NS="practica-ibdn"
JOB_NAME="model-training"

echo "======================================"
echo " REENTRENANDO MODELO EN KUBERNETES"
echo "======================================"
echo ""

echo "Comprobando namespace..."
kubectl get namespace "$NS" >/dev/null

echo "Comprobando servicios principales..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app=mlflow -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app=spark-master -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app=spark-worker -n "$NS" --timeout=300s

echo ""
echo "Eliminando job anterior si existe..."
kubectl delete job "$JOB_NAME" -n "$NS" --ignore-not-found

echo ""
echo "Lanzando job de entrenamiento..."
kubectl apply -f k8s/model-training-job.yaml

echo ""
echo "Esperando a que arranque el pod del job..."
kubectl wait --for=condition=ready pod -l app=model-training -n "$NS" --timeout=300s || true

echo ""
echo "Logs del entrenamiento:"
kubectl logs -n "$NS" job/"$JOB_NAME" -f

echo ""
echo "Comprobando finalización del job..."
kubectl wait --for=condition=complete job/"$JOB_NAME" -n "$NS" --timeout=3600s

echo ""
echo "Comprobando modelos en MinIO..."
MINIO_MODELS=$(kubectl run minio-check-models -n "$NS" --rm -i \
  --image=minio/mc:latest \
  --restart=Never \
  --command -- sh -c "mc alias set local http://minio:9000 admin password123 >/dev/null && mc ls local/warehouse/models" 2>/dev/null || true)

echo "$MINIO_MODELS"

echo "$MINIO_MODELS" | grep -q "spark_random_forest_classifier.flight_delays.5.0.bin" \
  && echo "✅ Modelo Random Forest guardado en MinIO" \
  || { echo "❌ No se encontró el modelo en MinIO"; exit 1; }

echo ""
echo "======================================"
echo " ✅ REENTRENAMIENTO KUBERNETES OK"
echo "======================================"
echo ""
echo "Para ver MLflow:"
echo "kubectl port-forward -n $NS svc/mlflow 5000:5000"
echo "http://localhost:5000"
echo ""
echo "Experimento esperado:"
echo "flight-delay-training"
