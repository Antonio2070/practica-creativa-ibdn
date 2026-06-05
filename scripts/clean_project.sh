#!/usr/bin/env bash

echo "=================================="
echo " LIMPIANDO PROYECTO"
echo "=================================="

rm -rf flight_prediction/target

find . -name "*.log" -delete

find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null

echo "Proyecto limpio"
