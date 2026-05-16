import os
import io
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import boto3
from sqlalchemy import create_engine, text

PG_HOST     = os.getenv("PG_HOST",     "postgres")
PG_PORT     = os.getenv("PG_PORT",     "5432")
PG_DB       = os.getenv("PG_DB",       "oilfield")
PG_USER     = os.getenv("PG_USER",     "oilfield")
PG_PASSWORD = os.getenv("PG_PASSWORD", "oilfield123")

MINIO_ENDPOINT   = os.getenv("MINIO_ENDPOINT",   "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET     = os.getenv("MINIO_BUCKET",     "oilfield")

TABLES = [
    "wells",
    "production",
    "well_telemetry",
    "well_targets",
    "pumps",
    "pump_sensors",
    "pump_failures",
    "deliveries",
    "drivers",
    "vehicles",
    "oil_stations",
]


def get_engine():
    url = f"postgresql+psycopg2://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"
    return create_engine(url, pool_pre_ping=True)


def get_s3():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )


def export_table(engine, s3, table):
    print(f"Exporting {table}...")
    with engine.connect() as conn:
        df = pd.read_sql(text(f"SELECT * FROM {table}"), conn)
    print(f"  {len(df)} rows read")

    buf = io.BytesIO()
    table_pa = pa.Table.from_pandas(df, preserve_index=False)
    pq.write_table(table_pa, buf, compression="snappy")
    buf.seek(0)

    key = f"{table}/{table}.parquet"
    s3.put_object(
        Bucket=MINIO_BUCKET,
        Key=key,
        Body=buf,
        ContentType="application/octet-stream",
        ContentLength=buf.getbuffer().nbytes,
    )
    print(f"  uploaded s3://{MINIO_BUCKET}/{key}")


def run():
    engine = get_engine()
    s3 = get_s3()
    print("Starting ETL pipeline")
    for table in TABLES:
        try:
            export_table(engine, s3, table)
        except Exception as e:
            print(f"ERROR on {table}: {e}")
    print("ETL pipeline complete")


if __name__ == "__main__":
    run()
