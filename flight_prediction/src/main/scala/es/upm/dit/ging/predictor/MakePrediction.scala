package es.upm.dit.ging.predictor

import org.apache.spark.ml.classification.RandomForestClassificationModel
import org.apache.spark.ml.feature.VectorAssembler
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions.{col, concat, from_json, lit, to_json}
import org.apache.spark.sql.types.{DataTypes, StructType}

object MakePrediction {

  def main(args: Array[String]): Unit = {
    println("Flight predictor starting...")

    val spark = SparkSession
      .builder
      .appName("FlightDelayStreamingPrediction")
      .master(sys.env.getOrElse("SPARK_MASTER_URL", "spark://spark-master:7077"))
      .config("spark.driver.host", sys.env.getOrElse("SPARK_DRIVER_HOST", "spark-predictor"))
      .config("spark.driver.bindAddress", "0.0.0.0")
      .config("spark.executor.instances", "2")
      .config("spark.executor.cores", "1")
      .config("spark.executor.memory", "1g")
      .getOrCreate()

    println("Spark master real: " + spark.sparkContext.master)
    println("Spark app id: " + spark.sparkContext.applicationId)
    
    import spark.implicits._

    //Load the arrival delay bucketizer
    val base_path= "/app" //Docker
    //val base_path= "/home/antonio/Documentos/IBDN/practica_creativa" //Parte 1

    // Load the numeric vector assembler
    val vectorAssemblerPath = "%s/models/numeric_vector_assembler.bin".format(base_path)
    val vectorAssembler = VectorAssembler.load(vectorAssemblerPath)

    // Load the classifier model
    val randomForestModelPath = "%s/models/spark_random_forest_classifier.flight_delays.5.0.bin".format(
      base_path)
    val rfc = RandomForestClassificationModel.load(randomForestModelPath)

    //Process Prediction Requests in Streaming
    val df = spark
      .readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", sys.env.getOrElse("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"))
      .option("subscribe", "flight-delay-ml-request")
      .load()
    df.printSchema()

    val flightJsonDf = df.selectExpr("CAST(value AS STRING)")

    val struct = new StructType()
      .add("Origin", DataTypes.StringType)
      .add("FlightNum", DataTypes.StringType)
      .add("DayOfWeek", DataTypes.IntegerType)
      .add("DayOfYear", DataTypes.IntegerType)
      .add("DayOfMonth", DataTypes.IntegerType)
      .add("Dest", DataTypes.StringType)
      .add("DepDelay", DataTypes.DoubleType)
      .add("Prediction", DataTypes.StringType)
      .add("Timestamp", DataTypes.TimestampType)
      .add("FlightDate", DataTypes.DateType)
      .add("Carrier", DataTypes.StringType)
      .add("UUID", DataTypes.StringType)
      .add("Distance", DataTypes.DoubleType)
      .add("Carrier_index", DataTypes.DoubleType)
      .add("Origin_index", DataTypes.DoubleType)
      .add("Dest_index", DataTypes.DoubleType)
      .add("Route_index", DataTypes.DoubleType)

    val flightNestedDf = flightJsonDf.select(from_json($"value", struct).as("flight"))
    flightNestedDf.printSchema()

  

    // Dataframe for Vectorizing numeric columns
    val flightFlattenedDf2 = flightNestedDf.selectExpr(
      "flight.Origin",
      "flight.FlightNum", //Se ha añadido este por cassandra
      "flight.DayOfWeek",
      "flight.DayOfYear",
      "flight.DayOfMonth",
      "flight.Dest",
      "flight.DepDelay",
      "flight.Timestamp",
      "flight.FlightDate",
      "flight.Carrier",
      "flight.UUID",
      "flight.Distance",
      "flight.Carrier_index",
      "flight.Origin_index",
      "flight.Dest_index",
      "flight.Route_index"
    )



    val predictionRequestsWithRouteMod2 = flightFlattenedDf2.withColumn(
      "Route",
      concat(
        flightFlattenedDf2("Origin"),
        lit('-'),
        flightFlattenedDf2("Dest")
      )
    )

    //Vectorize numeric columns: DepDelay, Distance and index columns
    val vectorizedFeatures = vectorAssembler.setHandleInvalid("keep").transform(predictionRequestsWithRouteMod2)

    // Inspect the vectors
    vectorizedFeatures.printSchema()

    // Drop the individual index columns
    val finalVectorizedFeatures = vectorizedFeatures
        .drop("Carrier_index")
        .drop("Origin_index")
        .drop("Dest_index")
        .drop("Route_index")

    // Inspect the finalized features
    finalVectorizedFeatures.printSchema()

    // Make the prediction
    val predictions = rfc.transform(finalVectorizedFeatures)
      .drop("Features_vec")

    // Drop the features vector and prediction metadata to give the original fields
    val finalPredictions = predictions.drop("indices").drop("values").drop("rawPrediction").drop("probability")

    // Inspect the output
    finalPredictions.printSchema()

    // ===============================
    // 1. Escribir predicciones en Kafka
    // ===============================
    val kafkaPredictions = finalPredictions
      .select(
        col("UUID").cast("string").as("key"),
        to_json(org.apache.spark.sql.functions.struct(finalPredictions.columns.map(col): _*)).as("value")
      )

    val kafkaQuery = kafkaPredictions
      .writeStream
      .format("kafka")
      .option("kafka.bootstrap.servers", sys.env.getOrElse("KAFKA_BOOTSTRAP_SERVERS", "kafka:29092"))
      .option("topic", "flight-delay-ml-response")
      .option("checkpointLocation", "/tmp/checkpoints/kafka_predictions")
      .outputMode("append")
      .start()

    // ===============================
    // 2. Guardar predicciones en Cassandra
    // ===============================
    val cassandraQuery = finalPredictions
      .select(
        col("UUID").cast("string").as("uuid"),
        col("Carrier").cast("string").as("carrier"),
        col("Origin").cast("string").as("origin"),
        col("Dest").cast("string").as("dest"),
        col("Route").cast("string").as("route"),
        col("FlightDate").cast("date").as("flight_date"),
        col("FlightNum").cast("string").as("flight_num"),
        col("DepDelay").cast("double").as("dep_delay"),
        col("Distance").cast("double").as("distance"),
        col("Timestamp").cast("timestamp").as("timestamp"),
        col("prediction").cast("double").as("prediction")
      )
      .writeStream
      .format("org.apache.spark.sql.cassandra")
      .option("keyspace", "agile_data_science")
      .option("table", "flight_delay_ml_response")
      .option("spark.cassandra.connection.host", sys.env.getOrElse("CASSANDRA_HOST", "cassandra"))
      .option("checkpointLocation", "/tmp/checkpoints/cassandra_predictions")
      .outputMode("append")
      .start()

    // Opcional: salida por consola para depurar
    val consoleOutput = finalPredictions.writeStream
      .outputMode("append")
      .format("console")
      .start()

    spark.streams.awaitAnyTermination()
      }

}
