import sys, os, re

from airflow import DAG
from airflow.operators.bash import BashOperator

from datetime import datetime, timedelta
import iso8601

PROJECT_HOME = os.getenv("PROJECT_HOME")


default_args = {
  'owner': 'airflow',
  'depends_on_past': False,
  'start_date': iso8601.parse_date("2016-12-01"),
  'retries': 3,
  'retry_delay': timedelta(minutes=5),
}

training_dag = DAG(
  'agile_data_science_batch_prediction_model_training',
  default_args=default_args,
  schedule_interval=None
)

# We use the same two commands for all our PySpark tasks
pyspark_bash_command = """
if [ -f /app/.models_lakehouse_ready ]; then
  echo 'Modelos ya entrenados. Saltando entrenamiento Airflow.';
else
  /app/spark-4.1.1-bin-hadoop3/bin/spark-submit \
    --master spark://spark-master:7077 \
    --driver-memory 4g \
    --conf spark.driver.host=airflow \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.executor.instances=2 \
    --conf spark.executor.cores=1 \
    --conf spark.executor.memory=1g \
    --conf spark.driver.extraJavaOptions=-Djava.net.preferIPv4Stack=true \
    --packages org.apache.iceberg:iceberg-spark-runtime-4.0_2.13:1.10.1,org.apache.hadoop:hadoop-aws:3.4.2 \
    /app/resources/train_spark_mllib_model_lakehouse.py \
  && touch /app/.models_lakehouse_ready;
fi
"""
pyspark_date_bash_command = """
spark-submit --master {{ params.master }} \
  {{ params.base_path }}/{{ params.filename }} \
  {{ ts }} {{ params.base_path }}
"""


# Gather the training data for our classifier
"""
extract_features_operator = BashOperator(
  task_id = "pyspark_extract_features",
  bash_command = pyspark_bash_command,
  params = {
    "master": "local[8]",
    "filename": "resources/extract_features.py",
    "base_path": "{}/".format(PROJECT_HOME)
  },
  dag=training_dag
)

"""

# Train and persist the classifier model
train_classifier_model_operator = BashOperator(
  task_id="pyspark_train_classifier_model_lakehouse",
  bash_command=pyspark_bash_command,
  dag=training_dag
)

# The model training depends on the feature extraction
#train_classifier_model_operator.set_upstream(extract_features_operator)
