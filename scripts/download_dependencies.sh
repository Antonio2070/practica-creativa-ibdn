#!/usr/bin/env bash

set -e

SPARK_VERSION="4.1.1"
SPARK_PACKAGE="spark-${SPARK_VERSION}-bin-hadoop3"
SPARK_TGZ="${SPARK_PACKAGE}.tgz"
SPARK_URL="https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}"

KAFKA_VERSION="4.2.0"
KAFKA_SCALA_VERSION="2.13"
KAFKA_PACKAGE="kafka_${KAFKA_SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_TGZ="${KAFKA_PACKAGE}.tgz"
KAFKA_URL="https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_TGZ}"

echo "======================================"
echo " DESCARGANDO DEPENDENCIAS"
echo "======================================"

if [ ! -f "$SPARK_TGZ" ]; then
  echo "Descargando $SPARK_TGZ..."
  wget -O "$SPARK_TGZ" "$SPARK_URL"
else
  echo "$SPARK_TGZ ya existe"
fi

if [ ! -d "$SPARK_PACKAGE" ]; then
  echo "Descomprimiendo $SPARK_TGZ..."
  tar -xzf "$SPARK_TGZ"
else
  echo "$SPARK_PACKAGE ya existe"
fi

if [ ! -f "$KAFKA_TGZ" ]; then
  echo "Descargando $KAFKA_TGZ..."
  wget -O "$KAFKA_TGZ" "$KAFKA_URL"
else
  echo "$KAFKA_TGZ ya existe"
fi

if [ ! -d "$KAFKA_PACKAGE" ]; then
  echo "Descomprimiendo $KAFKA_TGZ..."
  tar -xzf "$KAFKA_TGZ"
else
  echo "$KAFKA_PACKAGE ya existe"
fi

echo "Dependencias listas."
