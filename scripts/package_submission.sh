#!/usr/bin/env bash

./scripts/clean_project.sh

ZIP_NAME="practica_creativa_entrega.zip"

rm -f "$ZIP_NAME"

zip -r "$ZIP_NAME" . \
  -x "env/*" \
  -x "flight_prediction/target/*" \
  -x "kafka_2.13-4.2.0/*" \
  -x "spark-4.1.1-bin-hadoop3/*" \
  -x "*.log" \
  -x ".git/*"

echo ""
echo "Generado: $ZIP_NAME"

