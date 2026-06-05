#!/usr/bin/env python3

from pyspark.sql import SparkSession
from pyspark.sql.functions import lit, concat
from pyspark.ml.feature import Bucketizer, StringIndexer, VectorAssembler
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import MulticlassClassificationEvaluator

import os
import mlflow

spark = (
    SparkSession.builder
    .appName("train_spark_mllib_model_lakehouse")
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

mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://mlflow:5000"))
mlflow.set_experiment("flight-delay-training")

print("Leyendo datos de entrenamiento desde Iceberg...")

features = spark.table("local.flight_delay.training_features")

#print("Filas de entrenamiento:", features.count())

training_rows = features.count()
print("Filas de entrenamiento:", training_rows)

features_with_route = features.withColumn(
    "Route",
    concat(features.Origin, lit("-"), features.Dest)
)

splits = [-float("inf"), -15.0, 0, 30.0, float("inf")]

arrival_bucketizer = Bucketizer(
    splits=splits,
    inputCol="ArrDelay",
    outputCol="ArrDelayBucket"
)

models_base_path = "s3a://warehouse/models"

arrival_bucketizer.write().overwrite().save(
    f"{models_base_path}/arrival_bucketizer_2.0.bin"
)

ml_bucketized_features = arrival_bucketizer.transform(features_with_route)

for column in ["Carrier", "Origin", "Dest", "Route"]:
    string_indexer = StringIndexer(
        inputCol=column,
        outputCol=column + "_index"
    )

    string_indexer_model = string_indexer.fit(ml_bucketized_features)
    ml_bucketized_features = string_indexer_model.transform(ml_bucketized_features)
    ml_bucketized_features = ml_bucketized_features.drop(column)

    string_indexer_model.write().overwrite().save(
        f"{models_base_path}/string_indexer_model_{column}.bin"
    )

numeric_columns = [
    "DepDelay",
    "Distance",
    "DayOfMonth",
    "DayOfWeek",
    "DayOfYear"
]

index_columns = [
    "Carrier_index",
    "Origin_index",
    "Dest_index",
    "Route_index"
]

vector_assembler = VectorAssembler(
    inputCols=numeric_columns + index_columns,
    outputCol="Features_vec"
)

final_vectorized_features = vector_assembler.transform(ml_bucketized_features)

vector_assembler.write().overwrite().save(
    f"{models_base_path}/numeric_vector_assembler.bin"
)

for column in index_columns:
    final_vectorized_features = final_vectorized_features.drop(column)

rfc = RandomForestClassifier(
    featuresCol="Features_vec",
    labelCol="ArrDelayBucket",
    predictionCol="Prediction",
    maxBins=4657,
    maxMemoryInMB=1024
)

# print("Entrenando modelo Random Forest...")

# model = rfc.fit(final_vectorized_features)

# model.write().overwrite().save(
#     f"{models_base_path}/spark_random_forest_classifier.flight_delays.5.0.bin"
# )

# predictions = model.transform(final_vectorized_features)

# evaluator = MulticlassClassificationEvaluator(
#     predictionCol="Prediction",
#     labelCol="ArrDelayBucket",
#     metricName="accuracy"
# )

# accuracy = evaluator.evaluate(predictions)

# print("Accuracy =", accuracy)

# predictions.groupBy("Prediction").count().show()

# print("Modelo guardado en MinIO/S3:")
# print(models_base_path)

# spark.stop()

print("Entrenando modelo Random Forest...")

with mlflow.start_run(run_name="spark-random-forest-lakehouse"):
    mlflow.log_param("model_type", "RandomForestClassifier")
    mlflow.log_param("training_source", "local.flight_delay.training_features")
    mlflow.log_param("models_output_path", models_base_path)
    mlflow.log_param("features_output_col", "Features_vec")
    mlflow.log_param("label_col", "ArrDelayBucket")
    mlflow.log_param("prediction_col", "Prediction")
    mlflow.log_param("maxBins", 4657)
    mlflow.log_param("maxMemoryInMB", 1024)

    mlflow.log_metric("training_rows", training_rows)

    model = rfc.fit(final_vectorized_features)

    model.write().overwrite().save(
        f"{models_base_path}/spark_random_forest_classifier.flight_delays.5.0.bin"
    )

    predictions = model.transform(final_vectorized_features)

    evaluator = MulticlassClassificationEvaluator(
        predictionCol="Prediction",
        labelCol="ArrDelayBucket",
        metricName="accuracy"
    )

    accuracy = evaluator.evaluate(predictions)

    mlflow.log_metric("accuracy", accuracy)

    print("Accuracy =", accuracy)

    predictions.groupBy("Prediction").count().show()

    print("Modelo guardado en MinIO/S3:")
    print(models_base_path)

spark.stop()