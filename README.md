# Práctica Creativa IBDN – Sistema de Predicción de Retrasos de Vuelos

## Descripción

Este proyecto implementa un sistema de predicción de retrasos de vuelos en tiempo real utilizando tecnologías Big Data y Cloud Native.

La arquitectura está basada en:

* Apache Kafka para mensajería y streaming.
* Apache Spark Structured Streaming para inferencia en tiempo real.
* Apache Cassandra para persistencia de datos.
* Flask para la interfaz web.
* MinIO como almacenamiento compatible con S3.
* MLflow para gestión de modelos.
* Docker Compose para despliegue local.
* Kubernetes (Minikube) para despliegue cloud-native.

El sistema recibe peticiones desde una interfaz web, genera eventos en Kafka, Spark procesa las predicciones utilizando modelos previamente entrenados y almacena los resultados en Cassandra.

---

# Arquitectura

```text
Usuario
   |
   v
Flask Web
   |
   v
Kafka (flight-delay-ml-request)
   |
   v
Spark Streaming Predictor
   |
   +--> Cassandra
   |
   +--> Kafka (flight-delay-ml-response)
   |
   v
Flask WebSocket
```

Servicios auxiliares:

```text
MinIO  <--> Spark
MLflow <--> Spark
```

---

# Estructura del Proyecto

```text
practica_creativa/
│
├── data/
├── flight_prediction/
├── resources/
├── models/
├── k8s/
├── scripts/
│
├── docker-compose.yml
├── Dockerfile.spark
├── Dockerfile.web
├── Dockerfile.airflow
├── requirements.txt
└── README.md
```

## Carpetas principales

### data/

Contiene los datasets utilizados por la práctica:

* origin_dest_distances.jsonl
* simple_flight_delay_features.jsonl.bz2

### flight_prediction/

Código Scala/Spark encargado de realizar las predicciones en streaming.

### resources/

Scripts auxiliares:

* Importación de datos.
* Entrenamiento de modelos.
* Utilidades Kafka.
* Aplicación web Flask.

### models/

Modelos previamente entrenados:

* Random Forest Spark MLlib.
* String Indexers.
* Vector Assembler.
* Modelos Scikit-Learn.

### k8s/

Manifiestos Kubernetes:

* namespace
* kafka
* cassandra
* minio
* mlflow
* spark master
* spark workers
* spark predictor
* flask web

### scripts/

Scripts de automatización:

* k8s_deploy.sh
* k8s_check.sh
* stack_status.sh
* wait_stack_ready.sh

---

# Requisitos

## Docker

* Docker Engine
* Docker Compose

## Kubernetes

* Minikube
* kubectl

---

# Despliegue con Docker Compose

## Construcción

```bash
docker compose build
```

## Arranque

```bash
docker compose up -d
```

## Comprobación

```bash
docker ps
```

Servicios disponibles:

| Servicio | URL                   |
| -------- | --------------------- |
| Flask    | http://localhost:5001 |
| MLflow   | http://localhost:5000 |
| Spark UI | http://localhost:8081 |
| Airflow  | http://localhost:8080 |
| MinIO    | http://localhost:9001 |

---

# Despliegue con Kubernetes

## Construcción de imágenes

```bash
eval $(minikube docker-env)

docker build -t practica-spark:latest -f Dockerfile.spark .
docker build -t practica-web:latest -f Dockerfile.web .
docker build -t practica-airflow:latest -f Dockerfile.airflow .
```

## Despliegue

```bash
./scripts/k8s_deploy.sh
```

## Verificación

```bash
./scripts/k8s_check.sh
```

---

# Servicios Kubernetes

## Flask

```bash
minikube service flask-web -n practica-ibdn
```

## Spark UI

```bash
kubectl port-forward -n practica-ibdn svc/spark-master 8081:8081
```

## MLflow

```bash
kubectl port-forward -n practica-ibdn svc/mlflow 5000:5000
```

---

# Mejoras Implementadas

## Despliegue

* Dockerización completa.
* Despliegue completo en Kubernetes.
* Automatización mediante scripts.

## Persistencia

* Cassandra para resultados.
* MinIO como almacenamiento S3.

## Observabilidad

* Spark UI.
* MLflow.
* Logs gestionados por Kubernetes.

## Escalabilidad

* Spark Master + múltiples Workers.
* Gestión de réplicas mediante Kubernetes.

---

# Validación

La validación del despliegue se realiza mediante:

```bash
./scripts/k8s_check.sh
```

Este script comprueba:

* Estado de los pods.
* Topics Kafka.
* Datos en Cassandra.
* Bucket MinIO.
* Spark Cluster.
* Spark Streaming.
* MLflow.
* Aplicación Flask.

```
```

