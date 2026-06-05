#!/usr/bin/env python3

from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField,
    StringType, IntegerType, DoubleType,
    DateType, TimestampType
)

spark = (
    SparkSession.builder
    .appName("import_training_data_iceberg")
    .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.local.type", "hadoop")
    .config("spark.sql.catalog.local.warehouse", "s3a://warehouse/iceberg")
    .config("spark.hadoop.fs.s3a.endpoint", "http://minio:9000")
    .config("spark.hadoop.fs.s3a.access.key", "admin")
    .config("spark.hadoop.fs.s3a.secret.key", "password123")
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    .getOrCreate()
)

schema = StructType([
    StructField("ArrDelay", DoubleType(), True),
    StructField("CRSArrTime", TimestampType(), True),
    StructField("CRSDepTime", TimestampType(), True),
    StructField("Carrier", StringType(), True),
    StructField("DayOfMonth", IntegerType(), True),
    StructField("DayOfWeek", IntegerType(), True),
    StructField("DayOfYear", IntegerType(), True),
    StructField("DepDelay", DoubleType(), True),
    StructField("Dest", StringType(), True),
    StructField("Distance", DoubleType(), True),
    StructField("FlightDate", DateType(), True),
    StructField("FlightNum", StringType(), True),
    StructField("Origin", StringType(), True),
])

input_path = "/app/data/simple_flight_delay_features.jsonl.bz2"

features = spark.read.json(input_path, schema=schema)

print("Filas leídas desde JSON original:", features.count())

spark.sql("CREATE NAMESPACE IF NOT EXISTS local.flight_delay")

features.writeTo("local.flight_delay.training_features") \
    .using("iceberg") \
    .createOrReplace()

print("Tabla Iceberg creada correctamente: local.flight_delay.training_features")

spark.sql("""
SELECT COUNT(*) AS total
FROM local.flight_delay.training_features
""").show()

spark.stop()
