# Práctica Creativa IBDN – Sistema de Predicción de Retrasos de Vuelos

## 1. Descripción

Este proyecto implementa un sistema Big Data para la predicción de retrasos de vuelos en tiempo real.

El sistema permite:

* Enviar peticiones de predicción desde una aplicación web Flask.
* Publicar solicitudes en Kafka.
* Procesar las solicitudes con Spark Structured Streaming.
* Aplicar modelos de Machine Learning previamente entrenados.
* Guardar resultados en Cassandra.
* Devolver la predicción a la web mediante Kafka y WebSockets.
* Almacenar datos y modelos en MinIO usando Iceberg como Lakehouse.
* Registrar entrenamientos en MLflow.
* Orquestar entrenamiento con Airflow en Docker.
* Desplegar el escenario tanto con Docker Compose como con Kubernetes/Minikube.

---

## 2. Tecnologías utilizadas

* Apache Kafka
* Apache Spark Structured Streaming
* Apache Cassandra
* Flask
* MinIO
* Apache Iceberg
* MLflow
* Apache Airflow
* Docker / docker-compose
* Kubernetes / Minikube

---

## 3. Arquitectura general

Flujo principal de inferencia:

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

Flujo de entrenamiento:

```text
Datos de entrenamiento
   |
   v
MinIO / Iceberg Lakehouse
   |
   v
Spark Training
   |
   +--> MLflow
   |
   v
Modelos guardados en MinIO
```

---

## 4. Arquitectura Docker

El despliegue Docker utiliza `docker-compose.yml` y levanta el escenario completo:

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

En Docker, Airflow puede lanzar el entrenamiento del modelo mediante Spark contra el cluster Spark. MLflow registra el experimento, sus parámetros y métricas.

---

## 5. Arquitectura Kubernetes

El despliegue Kubernetes utiliza el namespace:

```text
practica-ibdn
```

Los manifiestos se encuentran en `k8s/`.

Servicios desplegados:

* Cassandra
* Kafka
* MinIO
* MLflow
* Spark Master
* Spark Workers
* Spark Predictor
* Flask Web
* Job de inicialización de Cassandra
* Job de inicialización de MinIO
* Job opcional de entrenamiento del modelo

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
│   ├── arrival_bucketizer_2.0.bin
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
│   ├── cassandra.yaml
│   ├── cassandra-init.yaml
│   ├── kafka.yaml
│   ├── minio.yaml
│   ├── minio-init.yaml
│   ├── mlflow.yaml
│   ├── model-training-job.yaml
│   ├── spark-master.yaml
│   ├── spark-worker.yaml
│   ├── spark-predictor.yaml
│   └── flask-web.yaml
│
├── scripts/
│   ├── docker_start.sh
│   ├── docker_stop.sh
│   ├── docker_retrain_models.sh
│   ├── download_dependencies.sh
│   ├── k8s_start.sh
│   ├── k8s_deploy.sh
│   ├── k8s_check.sh
│   ├── k8s_retrain_models.sh
│   ├── k8s_stop.sh
│   ├── stack_status.sh
│   ├── start_all.sh
│   └── wait_stack_ready.sh
│
├── docker-compose.yml
├── Dockerfile.spark
├── Dockerfile.web
├── Dockerfile.airflow
├── requirements.txt
└── README.md
```

---

## 7. Ficheros necesarios

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

No es necesario versionar ni entregar:

```text
env/
flight_prediction/target/
flight_prediction/project/target/
kafka_2.13-4.2.0/
kafka_2.13-4.2.0.tgz
spark-4.1.1-bin-hadoop3/
spark-4.1.1-bin-hadoop3.tgz
*.log
.git/
```

Las dependencias pesadas de Spark y Kafka se descargan mediante:

```bash
./scripts/download_dependencies.sh
```

---

## 8. Requisitos

### Software necesario

* Python 3
* Java
* SBT
* Docker
* docker-compose
* Minikube
* kubectl

### Entorno Python

Crear entorno virtual:

```bash
python3 -m venv env
```

Activar entorno:

```bash
source env/bin/activate
```

Instalar dependencias:

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 9. Preparación de dependencias

Antes de construir las imágenes, se descargan Spark y Kafka:

```bash
./scripts/download_dependencies.sh
```

Este script descarga:

* `spark-4.1.1-bin-hadoop3.tgz`
* `kafka_2.13-4.2.0.tgz`

y descomprime las carpetas necesarias.

---

## 10. Compilación del predictor Spark

El predictor Scala necesita generar un `.jar`.

Desde la raíz del proyecto:

```bash
cd flight_prediction
sbt package
cd ..
```

Esto genera el JAR en:

```text
flight_prediction/target/scala-2.13/
```

Los scripts de arranque pueden ejecutar esta compilación antes de construir las imágenes para evitar depender de artefactos generados en Git.

---

## 11. Despliegue con Docker

### Arrancar Docker

```bash
./scripts/docker_start.sh
```

Este script:

1. Descarga dependencias si es necesario.
2. Construye las imágenes.
3. Lanza el escenario con `docker-compose`.
4. Espera a que todos los servicios estén disponibles.

### Comprobar estado Docker

```bash
./scripts/stack_status.sh
```

### Parar Docker

```bash
./scripts/docker_stop.sh
```

---

## 12. Servicios Docker

| Servicio  | URL                   |
| --------- | --------------------- |
| Flask Web | http://localhost:5001 |
| Spark UI  | http://localhost:8081 |
| Airflow   | http://localhost:8080 |
| MLflow    | http://localhost:5000 |
| MinIO     | http://localhost:9001 |

---

## 13. Reentrenamiento con Docker, Airflow y MLflow

Para entrenar un modelo desde cero usando Airflow:

```bash
./scripts/docker_retrain_models.sh
```

Este script:

1. Elimina la marca `resources/airflow/.models_lakehouse_ready`.
2. Lanza el DAG `agile_data_science_batch_prediction_model_training`.
3. Ejecuta Spark contra `spark://spark-master:7077`.
4. Lee los datos desde Iceberg/MinIO.
5. Guarda los modelos en MinIO.
6. Registra el experimento en MLflow.

MLflow estará disponible en:

```text
http://localhost:5000
```

El experimento esperado es:

```text
flight-delay-training
```

---

## 14. Despliegue con Kubernetes

### Arrancar Kubernetes

```bash
./scripts/k8s_start.sh
```

Este script:

1. Comprueba o arranca Minikube.
2. Configura el entorno Docker de Minikube.
3. Descarga dependencias si es necesario.
4. Construye las imágenes necesarias.
5. Despliega todos los manifiestos Kubernetes.
6. Ejecuta la comprobación automática del stack.

### Desplegar manualmente

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

### Comprobar Kubernetes

```bash
./scripts/k8s_check.sh
```

El script comprueba:

* Pods en estado `Ready`.
* Topics Kafka.
* Datos en Cassandra.
* Bucket `warehouse` en MinIO.
* Spark Master con workers vivos.
* Aplicación `FlightDelayStreamingPrediction`.
* MLflow.
* Flask Web.

### Parar Kubernetes

```bash
./scripts/k8s_stop.sh
```

Para parar Minikube completamente:

```bash
minikube stop
```

---

## 15. Servicios Kubernetes

### Flask Web

```bash
minikube service flask-web -n practica-ibdn
```

### Spark UI

```bash
kubectl port-forward -n practica-ibdn svc/spark-master 8081:8081
```

Abrir:

```text
http://localhost:8081
```

### MLflow

```bash
kubectl port-forward -n practica-ibdn svc/mlflow 5000:5000
```

Abrir:

```text
http://localhost:5000
```

---

## 16. Reentrenamiento en Kubernetes

Para entrenar un modelo desde cero en Kubernetes:

```bash
./scripts/k8s_retrain_models.sh
```

Este script lanza el Job:

```text
k8s/model-training-job.yaml
```

El Job:

1. Espera a MinIO, MLflow y Spark.
2. Importa los datos de entrenamiento a Iceberg.
3. Ejecuta el entrenamiento desde Iceberg.
4. Guarda los modelos en MinIO.
5. Registra el experimento en MLflow.

Para ver MLflow:

```bash
kubectl port-forward -n practica-ibdn svc/mlflow 5000:5000
```

Abrir:

```text
http://localhost:5000
```

---

## 17. Validación funcional

La validación principal consiste en comprobar el flujo completo:

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

Una ejecución correcta implica:

1. El usuario envía una predicción desde Flask.
2. Aparece un mensaje en `flight-delay-ml-request`.
3. Spark Streaming procesa la petición.
4. Aparece una respuesta en `flight-delay-ml-response`.
5. La tabla `flight_delay_ml_response` de Cassandra aumenta.
6. La predicción aparece en la web.

---

# 18. Requisitos de la Asignación Completados

## Requisitos Obligatorios (5/5)

### ✅ 1. Datos de entrenamiento almacenados en S3/MinIO utilizando Iceberg Lakehouse

Implementado.

* MinIO desplegado como almacenamiento de objetos compatible con S3.
* Catálogo Iceberg configurado sobre MinIO.
* Conjunto de datos de entrenamiento importado en tablas Iceberg.
* Inicialización automática disponible mediante scripts de despliegue.

---

### ✅ 2. Distancias de vuelo almacenadas y leídas desde Cassandra

Implementado.

Cambios realizados:

* Las distancias entre origen y destino fueron importadas a Cassandra.
* Se eliminó la dependencia de MongoDB en el flujo de consulta de distancias.
* La aplicación Flask obtiene las distancias directamente desde Cassandra.

Tabla utilizada:

```text
agile_data_science.origin_dest_distances
```

---

### ✅ 3. Predicciones escritas en Kafka y presentadas mediante WebSockets

Implementado.

Flujo de trabajo:

```text
Flask
 → Topic de solicitud en Kafka
 → Spark Streaming
 → Topic de respuesta en Kafka
 → WebSocket de Flask
 → Interfaz Web
```

Además:

* Las predicciones se almacenan de forma persistente en Cassandra.
* Las respuestas en tiempo real se consumen desde Kafka.
* Los resultados se muestran sin necesidad de recargar la página.

Tabla utilizada:

```text
agile_data_science.flight_delay_ml_response
```

---

### ✅ 4. El entrenamiento lee desde el Lakehouse y almacena los modelos en el Lakehouse

Implementado.

Flujo de entrenamiento:

```text
Iceberg Lakehouse
 → Entrenamiento con Spark ML
 → MinIO
 → MLflow
```

Los modelos pueden reentrenarse mediante:

```bash
./scripts/docker_retrain_models.sh
```

o

```bash
./scripts/k8s_retrain_models.sh
```

---

### ✅ 5. Despliegue completo con Docker

Implementado.

Servicios contenedorizados:

* Kafka
* Cassandra
* MinIO
* MLflow
* Airflow
* Spark Master
* Spark Workers
* Spark Predictor
* Aplicación Web Flask

Despliegue completo:

```bash
./scripts/docker_start.sh
```

---

## Despliegue en Kubernetes (3/3)

### ✅ Despliegue completo en Kubernetes con todas las modificaciones solicitadas

Implementado.

Servicios desplegados:

* Kafka
* Cassandra
* MinIO
* MLflow
* Spark Master
* Spark Workers
* Spark Predictor
* Aplicación Web Flask

Tareas de inicialización:

* Inicialización de Cassandra
* Inicialización de MinIO

Script de validación:

```bash
./scripts/k8s_check.sh
```

---

## Mejoras Adicionales

### ✅ Entrenamiento con Airflow + MLflow sobre un clúster Spark

Implementado.

* Un DAG de Airflow ejecuta el entrenamiento en Spark.
* MLflow almacena experimentos y ejecuciones.
* El entrenamiento puede repetirse bajo demanda.

---

### ⏳ Despliegue en Google Cloud

No implementado.

---

### ✅ Mejoras en despliegue, observabilidad y automatización

Implementado.

Principales mejoras:

* Scripts de despliegue automatizados.
* Scripts de validación automatizados.
* Scripts de reentrenamiento automatizados.
* Integración con Spark UI.
* Integración con MLflow.
* Tareas de inicialización de MinIO.
* Tareas de inicialización de Cassandra.
* Compatibilidad con Docker y Kubernetes.
* Flujo de validación de extremo a extremo (end-to-end).
* Repositorio GitHub con despliegue reproducible.

---
## 19. Autor

Antonio

Práctica Creativa – Ingeniería Big Data en la Nube
