CREATE TABLE IF NOT EXISTS wells (
    well_id     SERIAL PRIMARY KEY,
    well_name   VARCHAR(50)  NOT NULL,
    field       VARCHAR(50),
    region      VARCHAR(50),
    depth_m     NUMERIC(8,2),
    status      VARCHAR(20)  DEFAULT 'active',
    start_date  DATE
);

CREATE TABLE IF NOT EXISTS production (
    prod_id      SERIAL PRIMARY KEY,
    well_id      INTEGER NOT NULL REFERENCES wells(well_id),
    prod_date    DATE    NOT NULL,
    oil_rate_m3  NUMERIC(10,3),
    water_cut    NUMERIC(5,2),
    gas_rate_m3  NUMERIC(10,3),
    downtime_hrs NUMERIC(5,2)   DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_production_date    ON production(prod_date);
CREATE INDEX IF NOT EXISTS idx_production_well_id ON production(well_id);

CREATE TABLE IF NOT EXISTS telemetry (
    telem_id      SERIAL PRIMARY KEY,
    well_id       INTEGER   NOT NULL REFERENCES wells(well_id),
    recorded_at   TIMESTAMP NOT NULL,
    pressure_bar  NUMERIC(8,3),
    temperature_c NUMERIC(6,2),
    flow_rate_m3h NUMERIC(8,3),
    rpm           NUMERIC(7,2)
);

CREATE INDEX IF NOT EXISTS idx_telemetry_well_id ON telemetry(well_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_time    ON telemetry(recorded_at);

CREATE TABLE IF NOT EXISTS well_targets (
    target_id      SERIAL PRIMARY KEY,
    well_id        INTEGER   NOT NULL REFERENCES wells(well_id),
    measured_at    TIMESTAMP NOT NULL,
    pressure_bar   NUMERIC(8,3),
    temperature_c  NUMERIC(6,2),
    power_kw       NUMERIC(8,3),
    pump_runtime_h NUMERIC(6,2),
    flow_rate_m3h  NUMERIC(8,3)
);

CREATE TABLE IF NOT EXISTS pump_sensors (
    sensor_id      SERIAL PRIMARY KEY,
    well_id        INTEGER   NOT NULL REFERENCES wells(well_id),
    recorded_at    TIMESTAMP NOT NULL,
    vibration_mm_s NUMERIC(7,4),
    temperature_c  NUMERIC(6,2),
    current_a      NUMERIC(7,3),
    rpm            NUMERIC(7,2)
);

CREATE INDEX IF NOT EXISTS idx_pump_sensors_well ON pump_sensors(well_id);
CREATE INDEX IF NOT EXISTS idx_pump_sensors_time ON pump_sensors(recorded_at);

CREATE TABLE IF NOT EXISTS pump_failures (
    failure_id   SERIAL PRIMARY KEY,
    well_id      INTEGER   NOT NULL REFERENCES wells(well_id),
    failed_at    TIMESTAMP NOT NULL,
    failure_type VARCHAR(100),
    severity     VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS deliveries (
    delivery_id  SERIAL PRIMARY KEY,
    route_id     VARCHAR(20),
    driver_id    INTEGER,
    origin       VARCHAR(100),
    destination  VARCHAR(100),
    distance_km  NUMERIC(8,2),
    volume_t     NUMERIC(8,3),
    cost_rub     NUMERIC(12,2),
    planned_date DATE,
    actual_date  DATE,
    delay_days   INTEGER GENERATED ALWAYS AS (actual_date - planned_date) STORED,
    weather      VARCHAR(30),
    road_type    VARCHAR(30)
);

CREATE INDEX IF NOT EXISTS idx_deliveries_driver  ON deliveries(driver_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_route   ON deliveries(route_id);

CREATE OR REPLACE VIEW v_daily_production AS
SELECT
    prod_date,
    SUM(oil_rate_m3)            AS total_oil_m3,
    SUM(gas_rate_m3)            AS total_gas_m3,
    AVG(water_cut)              AS avg_water_cut,
    SUM(downtime_hrs)           AS total_downtime_hrs,
    COUNT(DISTINCT well_id)     AS active_wells
FROM production
GROUP BY prod_date
ORDER BY prod_date;

CREATE OR REPLACE VIEW v_well_kpi AS
SELECT
    w.well_id,
    w.well_name,
    w.field,
    w.region,
    w.status,
    ROUND(AVG(p.oil_rate_m3)::NUMERIC, 3)          AS avg_oil_rate,
    ROUND(SUM(p.oil_rate_m3)::NUMERIC, 3)          AS total_oil_m3,
    ROUND(AVG(p.water_cut)::NUMERIC, 2)             AS avg_water_cut,
    ROUND((100.0 * SUM(p.downtime_hrs) / NULLIF(COUNT(*) * 24, 0))::NUMERIC, 2) AS downtime_pct,
    COUNT(p.prod_date)                              AS production_days
FROM wells w
LEFT JOIN production p USING (well_id)
GROUP BY w.well_id, w.well_name, w.field, w.region, w.status;

CREATE OR REPLACE VIEW v_best_worst_wells AS
SELECT
    well_id,
    well_name,
    field,
    total_oil_m3,
    avg_oil_rate,
    downtime_pct,
    RANK() OVER (ORDER BY total_oil_m3 DESC) AS rank_best,
    RANK() OVER (ORDER BY total_oil_m3 ASC)  AS rank_worst
FROM v_well_kpi
WHERE total_oil_m3 IS NOT NULL;
