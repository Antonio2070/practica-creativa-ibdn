#!/usr/bin/env bash

set -e

NS="practica-ibdn"

echo "======================================"
echo " DESPLEGANDO STACK KUBERNETES IBDN"
echo "======================================"

echo ""
echo "Aplicando namespace..."
kubectl apply -f k8s/namespace.yaml

echo ""
echo "Aplicando servicios base..."
kubectl apply -f k8s/cassandra.yaml
kubectl apply -f k8s/kafka.yaml
kubectl apply -f k8s/minio.yaml
kubectl apply -f k8s/mlflow.yaml

echo ""
echo "Esperando Cassandra..."
kubectl wait --for=condition=ready pod -l app=cassandra -n "$NS" --timeout=600s

echo ""
echo "Esperando Kafka..."
kubectl wait --for=condition=ready pod -l app=kafka -n "$NS" --timeout=300s

echo ""
echo "Esperando MinIO..."
kubectl wait --for=condition=ready pod -l app=minio -n "$NS" --timeout=300s

echo ""
echo "Esperando MLflow..."
kubectl wait --for=condition=ready pod -l app=mlflow -n "$NS" --timeout=300s

echo ""
echo "Inicializando MinIO..."
kubectl delete job minio-init -n "$NS" --ignore-not-found
kubectl apply -f k8s/minio-init.yaml
kubectl wait --for=condition=complete job/minio-init -n "$NS" --timeout=300s

echo ""
echo "Inicializando Cassandra..."

kubectl delete pod cassandra-init-manual -n "$NS" --ignore-not-found

kubectl run cassandra-init-manual -n "$NS" \
  --image=practica-web:latest \
  --restart=Never \
  --image-pull-policy=IfNotPresent \
  --command -- sh -c "python3 /app/resources/import_distances_cassandra.py"

echo "Esperando a que cassandra-init termine..."
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/cassandra-init-manual -n "$NS" --timeout=900s

echo "Logs cassandra-init:"
kubectl logs -n "$NS" pod/cassandra-init-manual --tail=80

kubectl delete pod cassandra-init-manual -n "$NS" --ignore-not-found

echo "Cassandra inicializada correctamente."

echo ""
echo "Creando topics Kafka..."
kubectl exec -n "$NS" deploy/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:29092 \
  --create --if-not-exists \
  --topic flight-delay-ml-request \
  --partitions 1 \
  --replication-factor 1

kubectl exec -n "$NS" deploy/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:29092 \
  --create --if-not-exists \
  --topic flight-delay-ml-response \
  --partitions 1 \
  --replication-factor 1

echo ""
echo "Aplicando Spark..."
kubectl apply -f k8s/spark-master.yaml
kubectl apply -f k8s/spark-worker.yaml

kubectl wait --for=condition=ready pod -l app=spark-master -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app=spark-worker -n "$NS" --timeout=300s

echo ""
echo "Aplicando Spark Predictor y Flask..."
kubectl apply -f k8s/spark-predictor.yaml
kubectl apply -f k8s/flask-web.yaml

kubectl wait --for=condition=ready pod -l app=spark-predictor -n "$NS" --timeout=300s
kubectl wait --for=condition=ready pod -l app=flask-web -n "$NS" --timeout=300s

echo ""
echo "======================================"
echo " STACK KUBERNETES DESPLEGADO"
echo "======================================"
echo ""
kubectl get pods -n "$NS"
echo ""
echo "Flask Web:"
minikube service flask-web -n "$NS" --url || true
echo ""
echo "Spark UI:"
echo "kubectl port-forward -n $NS svc/spark-master 8081:8081"
echo ""
echo "MLflow:"
echo "kubectl port-forward -n $NS svc/mlflow 5000:5000"
