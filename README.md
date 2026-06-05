# Práctica Creativa IBDN – Sistema de Predicción de Retrasos de Vuelos

## 1. Descripción

Este proyecto implementa un sistema Big Data para la predicción de retrasos de vuelos en tiempo real.

El sistema permite enviar peticiones desde una aplicación web, publicarlas en Kafka, procesarlas con Spark Structured Streaming, aplicar modelos de Machine Learning previamente entrenados y almacenar las predicciones en Cassandra. Además, se incorporan MinIO como almacenamiento compatible con S3, MLflow para gestión de modelos y despliegues tanto con Docker Compose como con Kubernetes.

---

## 2. Tecnologías utilizadas

* Apache Kafka
* Apache Spark Structured Streaming
* Apache Cassandra
* Flask
* MinIO
* MLflow
* Airflow
* Docker Compose
* Kubernetes con Minikube

---

## 3. Arquitectura general

El flujo principal de inferencia en tiempo real es:

```text
Usuario
   |
   v
Flask Web
   |
   v
Kafka topic: flight-delay-ml-request
   |
   v
Spark Streaming Predictor
   |
   +--> Cassandra: flight_delay_ml_response
   |
   +--> Kafka topic: flight-delay-ml-response
   |
   v
Flask WebSocket
```

Además, el sistema incluye una parte de entrenamiento y gestión de modelos:

```text
Datos de entrenamiento
   |
   v
MinIO / Lakehouse
   |
   v
Spark Training
   |
   v
MLflow / Modelos
```

---

## 4. Arquitectura Docker

El despliegue Docker utiliza `docker-compose.yml` y levanta el escenario completo de la práctica:

* Kafka
* Kafka init
* Cassandra
* Cassandra init
* MinIO
* MinIO init
* Lakehouse init
* Spark Master
* Spark Workers
* Spark Predictor
* MLflow
* Airflow
* Flask Web

En Docker, Airflow se utiliza para lanzar el entrenamiento del modelo y generar la marca de modelos preparados. El script de espera comprueba que Cassandra, Kafka, MinIO, MLflow, los init containers, Airflow, Spark y Flask estén funcionando correctamente.

---

## 5. Arquitectura Kubernetes

El despliegue Kubernetes utiliza el namespace:

```text
practica-ibdn
```

Los manifiestos se encuentran en la carpeta `k8s/`.

Servicios desplegados:

* Cassandra
* Kafka
* MinIO
* MLflow
* Spark Master
* Spark Workers
* Spark Predictor
* Flask Web
* Jobs de inicialización para MinIO y Cassandra

En Kubernetes, el flujo validado es:

```text
Flask Web
   |
   v
Kafka request
   |
   v
Spark Predictor
   |
   +--> Cassandra
   |
   +--> Kafka response
   |
   v
Flask Web
```

---

## 6. Estructura del proyecto

```text
practica_creativa/
│
├── data/
│   ├── origin_dest_distances.jsonl
│   └── simple_flight_delay_features.jsonl.bz2
│
├── flight_prediction/
│   ├── build.sbt
│   ├── project/
│   └── src/
│
├── models/
│   ├── numeric_vector_assembler.bin
│   ├── spark_random_forest_classifier.flight_delays.5.0.bin
│   └── string_indexer_model_*.bin
│
├── resources/
│   ├── airflow/
│   ├── web/
│   ├── import_distances_cassandra.py
│   ├── import_training_data_iceberg.py
│   └── train_spark_mllib_model_lakehouse.py
│
├── k8s/
│   ├── namespace.yaml
│   ├── kafka.yaml
│   ├── cassandra.yaml
│   ├── cassandra-init.yaml
│   ├── minio.yaml
│   ├── minio-init.yaml
│   ├── mlflow.yaml
│   ├── spark-master.yaml
│   ├── spark-worker.yaml
│   ├── spark-predictor.yaml
│   └── flask-web.yaml
│
├── scripts/
│   ├── docker_start.sh
│   ├── docker_stop.sh
│   ├── k8s_start.sh
│   ├── k8s_deploy.sh
│   ├── k8s_check.sh
│   ├── k8s_stop.sh
│   ├── wait_stack_ready.sh
│   ├── stack_status.sh
│   ├── clean_project.sh
│   └── package_submission.sh
│
├── docker-compose.yml
├── Dockerfile.spark
├── Dockerfile.web
├── Dockerfile.airflow
├── requirements.txt
└── README.md
```

---

## 7. Ficheros necesarios para la entrega

Para ejecutar la práctica son necesarios:

```text
data/
flight_prediction/
models/
resources/
k8s/
scripts/
docker-compose.yml
Dockerfile.spark
Dockerfile.web
Dockerfile.airflow
requirements.txt
README.md
```

No es necesario entregar:

```text
env/
flight_prediction/target/
kafka_2.13-4.2.0/
spark-4.1.1-bin-hadoop3/
*.log
.git/
```

Estos elementos son dependencias descargadas, entornos virtuales o artefactos generados.

---

## 8. Requisitos

### Docker

* Docker
* docker-compose

### Kubernetes

* Minikube
* kubectl
* Docker

---

## 9. Despliegue con Docker

### Arrancar Docker

```bash
./scripts/docker_start.sh
```

Este script ejecuta:

```bash
docker-compose up -d --build
```

y después espera a que el stack esté completamente listo mediante:

```bash
./scripts/wait_stack_ready.sh
```

### Comprobar estado Docker

```bash
./scripts/stack_status.sh
```

### Parar Docker

```bash
./scripts/docker_stop.sh
```

---

## 10. Servicios Docker

| Servicio  | URL                   |
| --------- | --------------------- |
| Flask Web | http://localhost:5001 |
| Spark UI  | http://localhost:8081 |
| Airflow   | http://localhost:8080 |
| MLflow    | http://localhost:5000 |
| MinIO     | http://localhost:9001 |

---

## 11. Despliegue con Kubernetes

### Arrancar Kubernetes

```bash
./scripts/k8s_start.sh
```

Este script realiza las siguientes acciones:

1. Comprueba o arranca Minikube.
2. Configura el entorno Docker de Minikube.
3. Construye las imágenes:

   * `practica-spark:latest`
   * `practica-web:latest`
   * `practica-airflow:latest`
4. Ejecuta el despliegue Kubernetes.
5. Lanza la comprobación automática del stack.

### Despliegue Kubernetes

El despliegue se realiza mediante:

```bash
./scripts/k8s_deploy.sh
```

Este script:

* Aplica el namespace.
* Despliega Cassandra, Kafka, MinIO y MLflow.
* Inicializa MinIO.
* Inicializa Cassandra importando las distancias.
* Crea los topics Kafka.
* Despliega Spark Master y Spark Workers.
* Despliega Spark Predictor.
* Despliega Flask Web.

### Comprobación Kubernetes

```bash
./scripts/k8s_check.sh
```

El script comprueba:

* Pods en estado `Ready`.
* Topics Kafka.
* Tablas y datos en Cassandra.
* Bucket `warehouse` en MinIO.
* Spark Master con workers vivos.
* Aplicación `FlightDelayStreamingPrediction`.
* MLflow.
* Flask Web.

### Parar Kubernetes

```bash
./scripts/k8s_stop.sh
```

Este script elimina el namespace:

```text
practica-ibdn
```

Para parar Minikube completamente:

```bash
minikube stop
```

---

## 12. Servicios Kubernetes

### Flask Web

```bash
minikube service flask-web -n practica-ibdn
```

### Spark UI

```bash
kubectl port-forward -n practica-ibdn svc/spark-master 8081:8081
```

Después abrir:

```text
http://localhost:8081
```

### MLflow

```bash
kubectl port-forward -n practica-ibdn svc/mlflow 5000:5000
```

Después abrir:

```text
http://localhost:5000
```

---

## 13. Validación funcional

La validación principal consiste en comprobar que el flujo completo funciona:

```text
Flask
  |
  v
Kafka request
  |
  v
Spark Streaming
  |
  +--> Cassandra
  |
  +--> Kafka response
  |
  v
Flask Web
```

En una ejecución correcta:

1. El usuario envía una predicción desde Flask.
2. Aparece un mensaje en el topic `flight-delay-ml-request`.
3. Spark Streaming procesa la petición.
4. Aparece una respuesta en el topic `flight-delay-ml-response`.
5. La tabla `flight_delay_ml_response` de Cassandra aumenta.
6. La predicción aparece en la web.

---

## 14. Limpieza y empaquetado

Para limpiar artefactos generados:

```bash
./scripts/clean_project.sh
```

Para generar un ZIP de entrega:

```bash
./scripts/package_submission.sh
```

El ZIP excluye:

* `env/`
* `flight_prediction/target/`
* Kafka descargado
* Spark descargado
* logs
* `.git/`

---

## 15. Mejoras implementadas

### Despliegue

* Dockerización completa.
* Despliegue Kubernetes con Minikube.
* Automatización mediante scripts de arranque, parada y comprobación.

### Persistencia

* Cassandra para resultados de predicción.
* MinIO como almacenamiento compatible con S3.
* Inicialización automática de Cassandra y MinIO.

### Observabilidad

* Spark UI.
* MLflow.
* Logs mediante Docker y Kubernetes.
* Script de estado del stack Docker.
* Script de validación del stack Kubernetes.

### Escalabilidad

* Spark Master y Spark Workers.
* Despliegue de servicios mediante Kubernetes.
* Separación de componentes por servicio.

---

## 16. Autor

Antonio

Práctica Creativa – Ingeniería Big Data en la Nube
