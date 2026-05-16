import os
import io
import logging
import sys
from datetime import datetime

import boto3
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger(__name__)

PG_HOST     = os.getenv("PG_HOST",     "localhost")
PG_PORT     = os.getenv("PG_PORT",     "5432")
PG_DB       = os.getenv("PG_DB",       "oilfield")
PG_USER     = os.getenv("PG_USER",     "oilfield")
PG_PASSWORD = os.getenv("PG_PASSWORD", "oilfield123")

MINIO_ENDPOINT   = os.getenv("MINIO_ENDPOINT",   "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET     = os.getenv("MINIO_BUCKET",     "oilfield")

def get_engine():
    url = f"postgresql+psycopg2://{PG_USER}:{PG_PASSWORD}@{PG_HOST}:{PG_PORT}/{PG_DB}"
    log.info("Connecting to PostgreSQL: %s:%s/%s", PG_HOST, PG_PORT, PG_DB)
    return create_engine(url, pool_pre_ping=True)


def get_minio_client():
    log.info("Connecting to MinIO: %s", MINIO_ENDPOINT)
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
    )

def extract(engine, table: str) -> pd.DataFrame:
    log.info("Extracting table: %s", table)
    with engine.connect() as conn:
        df = pd.read_sql(text(f"SELECT * FROM {table}"), conn)
    log.info("  → %d rows, %d cols", len(df), len(df.columns))
    return df

def _add_date_parts(df: pd.DataFrame, date_col: str) -> pd.DataFrame:
    df[date_col] = pd.to_datetime(df[date_col])
    df["year"]   = df[date_col].dt.year
    df["month"]  = df[date_col].dt.month
    df["week"]   = df[date_col].dt.isocalendar().week.astype(int)
    return df


def transform_production(df: pd.DataFrame) -> pd.DataFrame:
    log.info("Transforming: production")
    df["oil_rate_m3"]  = df["oil_rate_m3"].clip(lower=0)
    df["gas_rate_m3"]  = df["gas_rate_m3"].clip(lower=0)
    df["downtime_hrs"] = df["downtime_hrs"].clip(lower=0, upper=24)
    df["water_cut"]    = df["water_cut"].clip(lower=0, upper=100)
    df = _add_date_parts(df, "prod_date")
    return df


def transform_telemetry(df: pd.DataFrame) -> pd.DataFrame:
    log.info("Transforming: telemetry")
    df["recorded_at"] = pd.to_datetime(df["recorded_at"])
    df = df.sort_values(["well_id", "recorded_at"])
    numeric_cols = ["pressure_bar", "temperature_c", "flow_rate_m3h", "rpm"]
    df[numeric_cols] = df.groupby("well_id")[numeric_cols].ffill()
    for col in ["pressure_bar", "flow_rate_m3h"]:
        df[f"{col}_rolling3"] = (
            df.groupby("well_id")[col]
            .transform(lambda x: x.rolling(3, min_periods=1).mean())
            .round(3)
        )
    df["year"]  = df["recorded_at"].dt.year
    df["month"] = df["recorded_at"].dt.month
    return df


def transform_well_targets(df: pd.DataFrame) -> pd.DataFrame:
    log.info("Transforming: well_targets")
    df["measured_at"] = pd.to_datetime(df["measured_at"])
    df = df.dropna(subset=["flow_rate_m3h"])
    df["pressure_norm"]     = (df["pressure_bar"]   - df["pressure_bar"].mean())   / df["pressure_bar"].std()
    df["temperature_norm"]  = (df["temperature_c"]  - df["temperature_c"].mean())  / df["temperature_c"].std()
    df["power_norm"]        = (df["power_kw"]        - df["power_kw"].mean())       / df["power_kw"].std()
    df["runtime_norm"]      = (df["pump_runtime_h"]  - df["pump_runtime_h"].mean()) / df["pump_runtime_h"].std()
    df["year"]  = df["measured_at"].dt.year
    df["month"] = df["measured_at"].dt.month
    return df


def transform_pump_sensors(df: pd.DataFrame) -> pd.DataFrame:
    log.info("Transforming: pump_sensors")
    df["recorded_at"] = pd.to_datetime(df["recorded_at"])
    sensor_cols = ["vibration_mm_s", "temperature_c", "current_a", "rpm"]
    for col in sensor_cols:
        mean = df[col].mean()
        std  = df[col].std()
        df[f"{col}_zscore"] = ((df[col] - mean) / std).round(4)
    df["year"]  = df["recorded_at"].dt.year
    df["month"] = df["recorded_at"].dt.month
    return df


def transform_deliveries(df: pd.DataFrame) -> pd.DataFrame:
    log.info("Transforming: deliveries")
    df["planned_date"] = pd.to_datetime(df["planned_date"])
    df["actual_date"]  = pd.to_datetime(df["actual_date"])
    df["cost_per_km"]  = (df["cost_rub"] / df["distance_km"]).round(2)
    df["delay_flag"]   = (df["delay_days"] > 0).astype(int)
    df["volume_flag"]  = pd.cut(
        df["volume_t"],
        bins=[0, 10, 25, 50, 9999],
        labels=["small", "medium", "large", "xl"],
    )
    df["year"]  = df["planned_date"].dt.year
    df["month"] = df["planned_date"].dt.month
    return df

def load_to_minio(client, df: pd.DataFrame, table: str) -> None:
    if df.empty:
        log.warning("Empty dataframe for %s, skipping", table)
        return

    if "year" in df.columns and "month" in df.columns:
        partitions = df.groupby(["year", "month"])
    else:
        df["year"]  = datetime.now().year
        df["month"] = datetime.now().month
        partitions = df.groupby(["year", "month"])

    total = 0
    for (year, month), part_df in partitions:
        key = f"{table}/year={year}/month={month:02d}/{table}.parquet"

        table_pa = pa.Table.from_pandas(part_df, preserve_index=False)
        buf = io.BytesIO()
        pq.write_table(table_pa, buf, compression="snappy")
        buf.seek(0)

        client.put_object(
            Bucket=MINIO_BUCKET,
            Key=key,
            Body=buf,
            ContentType="application/octet-stream",
            ContentLength=buf.getbuffer().nbytes,
        )
        log.info("  → uploaded s3://%s/%s (%d rows)", MINIO_BUCKET, key, len(part_df))
        total += len(part_df)

    log.info("Loaded %d total rows for '%s'", total, table)


PIPELINE = [
    ("wells",        lambda df: df),
    ("production",   transform_production),
    ("telemetry",    transform_telemetry),
    ("well_targets", transform_well_targets),
    ("pump_sensors", transform_pump_sensors),
    ("pump_failures",lambda df: df),
    ("deliveries",   transform_deliveries),
]


def run():
    engine = get_engine()
    s3     = get_minio_client()

    log.info("═" * 60)
    log.info("Starting ETL pipeline")
    log.info("═" * 60)

    errors = []
    for table, transform_fn in PIPELINE:
        try:
            df = extract(engine, table)
            df = transform_fn(df)
            load_to_minio(s3, df, table)
        except Exception as exc:
            log.error("FAILED table '%s': %s", table, exc)
            errors.append((table, exc))

    log.info("═" * 60)
    if errors:
        log.error("ETL completed with %d errors:", len(errors))
        for t, e in errors:
            log.error("  - %s: %s", t, e)
        sys.exit(1)
    else:
        log.info("ETL completed successfully ✓")


if __name__ == "__main__":
    run()
