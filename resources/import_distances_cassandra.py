import json
import time
from cassandra.cluster import Cluster

CASSANDRA_HOST = "cassandra"
KEYSPACE = "agile_data_science"
TABLE = "origin_dest_distances"
DATA_FILE = "/app/data/origin_dest_distances.jsonl"

print("Conectando a Cassandra...")

cluster = None
session = None

for i in range(30):
    try:
        cluster = Cluster([CASSANDRA_HOST])
        session = cluster.connect()
        print("Conectado a Cassandra")
        break
    except Exception as e:
        print(f"Cassandra no está lista todavía ({i+1}/30): {e}")
        time.sleep(5)

if session is None:
    raise RuntimeError("No se pudo conectar a Cassandra")

session.execute(f"""
CREATE KEYSPACE IF NOT EXISTS {KEYSPACE}
WITH replication = {{'class': 'SimpleStrategy', 'replication_factor': 1}}
""")

session.set_keyspace(KEYSPACE)

session.execute(f"""
CREATE TABLE IF NOT EXISTS {TABLE} (
  origin text,
  dest text,
  distance double,
  PRIMARY KEY (origin, dest)
)
""")

session.execute("""
CREATE TABLE IF NOT EXISTS flight_delay_ml_response (
  uuid text PRIMARY KEY,
  origin text,
  dest text,
  carrier text,
  flight_date date,
  flight_num text,
  dep_delay double,
  distance double,
  route text,
  prediction double,
  timestamp timestamp
)
""")

insert_stmt = session.prepare(f"""
INSERT INTO {TABLE} (origin, dest, distance)
VALUES (?, ?, ?)
""")

count = 0

with open(DATA_FILE, "r") as f:
    for line in f:
        if not line.strip():
            continue

        record = json.loads(line)

        origin = record["Origin"]
        dest = record["Dest"]
        distance = float(record["Distance"])

        session.execute(insert_stmt, (origin, dest, distance))
        count += 1

print(f"{count} distancias importadas correctamente en Cassandra")

cluster.shutdown()