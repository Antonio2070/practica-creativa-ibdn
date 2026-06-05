#!/bin/bash

PROJECT_HOME=$HOME/Documentos/IBDN/practica_creativa
KAFKA_HOME=$PROJECT_HOME/kafka_2.13-4.2.0
FLIGHT_PREDICTOR=$PROJECT_HOME/flight_prediction
WEB_APP=$PROJECT_HOME/resources/web

export PROJECT_HOME=$PROJECT_HOME
export SPARK_HOME=/opt/spark
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$SPARK_HOME/bin:$SPARK_HOME/sbin:$PATH

echo "🚀 Iniciando servicios..."

# =========================
# MONGO (BACKGROUND)
# =========================
echo "🟢 Arrancando MongoDB en background..."

docker start mongo >/dev/null 2>&1 || \
docker run -d --name mongo -p 27017:27017 mongo:4.2

sleep 3

# =========================
# KAFKA
# =========================
gnome-terminal --title="🟡 Kafka Server" -- bash -c "
echo 'Kafka iniciado';
cd $KAFKA_HOME;
bin/kafka-server-start.sh config/server.properties;
exec bash
"

sleep 5

# =========================
# SPARK
# =========================
gnome-terminal --title="🔵 Spark Streaming" -- bash -c "
echo 'Spark Streaming iniciado';
cd $FLIGHT_PREDICTOR;

JAR=\$(find target/scala-2.13 -name '*.jar' | head -n 1);

if [ -z \"\$JAR\" ]; then
  echo 'ERROR: No se ha encontrado el JAR. Ejecuta antes: sbt package';
  exec bash;
fi

echo 'Usando JAR:' \$JAR;

spark-submit \
--class es.upm.dit.ging.predictor.MakePrediction \
--master local[*] \
--packages org.mongodb.spark:mongo-spark-connector_2.13:10.4.1,org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.1 \
\$JAR;

exec bash
"

sleep 5

# =========================
# FLASK
# =========================
gnome-terminal --title="🟣 Flask Web (5001)" -- bash -c "
echo 'Flask iniciado en puerto 5001';
cd $WEB_APP;

source ../../env/bin/activate;

export PROJECT_HOME=$PROJECT_HOME;

python3 predict_flask.py;

exec bash
"

echo ""
echo "✅ Todo arrancado"
echo "👉 Abre: http://localhost:5001/flights/delays/predict_kafka"
echo ""