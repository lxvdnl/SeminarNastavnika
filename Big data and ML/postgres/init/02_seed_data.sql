INSERT INTO wells (well_name, field, region, depth_m, status, start_date) VALUES
('Скв-101', 'Самотлорское',   'ХМАО',         2850.0,  'active',      '2015-03-12'),
('Скв-102', 'Самотлорское',   'ХМАО',         2920.5,  'active',      '2015-06-20'),
('Скв-103', 'Самотлорское',   'ХМАО',         2775.0,  'idle',        '2016-01-08'),
('Скв-104', 'Приобское',      'ХМАО',         3100.0,  'active',      '2014-11-30'),
('Скв-105', 'Приобское',      'ХМАО',         3250.5,  'active',      '2014-08-15'),
('Скв-106', 'Приобское',      'ХМАО',         3180.0,  'maintenance', '2013-05-22'),
('Скв-201', 'Ванкорское',     'Красноярский', 2600.0,  'active',      '2018-04-10'),
('Скв-202', 'Ванкорское',     'Красноярский', 2680.0,  'active',      '2018-07-01'),
('Скв-203', 'Ванкорское',     'Красноярский', 2710.5,  'active',      '2019-02-14'),
('Скв-204', 'Ванкорское',     'Красноярский', 2590.0,  'idle',        '2019-09-18'),
('Скв-301', 'Юрубчено-Тохомское', 'Красноярский', 3400.0, 'active',  '2020-01-25'),
('Скв-302', 'Юрубчено-Тохомское', 'Красноярский', 3520.0, 'active',  '2020-04-30'),
('Скв-401', 'Мессояхское',   'ЯНАО',          2450.0,  'active',      '2017-06-11'),
('Скв-402', 'Мессояхское',   'ЯНАО',          2500.5,  'active',      '2017-09-03'),
('Скв-403', 'Мессояхское',   'ЯНАО',          2380.0,  'maintenance', '2016-12-19'),
('Скв-501', 'Тазовское',     'ЯНАО',          2200.0,  'active',      '2019-03-07'),
('Скв-502', 'Тазовское',     'ЯНАО',          2350.0,  'active',      '2019-07-22'),
('Скв-601', 'Бованенковское','ЯНАО',          1950.0,  'active',      '2021-05-15'),
('Скв-602', 'Бованенковское','ЯНАО',          2050.0,  'active',      '2021-08-28'),
('Скв-603', 'Бованенковское','ЯНАО',          1880.0,  'idle',        '2022-01-10');

INSERT INTO production (well_id, prod_date, oil_rate_m3, water_cut, gas_rate_m3, downtime_hrs)
SELECT
    w.well_id,
    d.day_date,
    GREATEST(0, ROUND((
        CASE w.well_id
            WHEN  1 THEN 95  WHEN  2 THEN 88  WHEN  3 THEN 45
            WHEN  4 THEN 120 WHEN  5 THEN 135 WHEN  6 THEN 30
            WHEN  7 THEN 78  WHEN  8 THEN 82  WHEN  9 THEN 91
            WHEN 10 THEN 42  WHEN 11 THEN 110 WHEN 12 THEN 105
            WHEN 13 THEN 68  WHEN 14 THEN 72  WHEN 15 THEN 25
            WHEN 16 THEN 55  WHEN 17 THEN 60  WHEN 18 THEN 48
            WHEN 19 THEN 51  ELSE 22
        END
        * (1 - 0.002 * (d.day_num - 1))
        + (RANDOM() * 10 - 5)
    )::NUMERIC, 3)),
    LEAST(95, GREATEST(5, ROUND((
        15 + 0.3 * d.day_num + RANDOM() * 8 - 4
    )::NUMERIC, 2))),
    GREATEST(0, ROUND((
        CASE w.well_id
            WHEN  1 THEN 18  WHEN  2 THEN 16  WHEN  3 THEN 8
            WHEN  4 THEN 24  WHEN  5 THEN 27  WHEN  6 THEN 5
            WHEN  7 THEN 14  WHEN  8 THEN 15  WHEN  9 THEN 17
            WHEN 10 THEN 7   WHEN 11 THEN 22  WHEN 12 THEN 20
            WHEN 13 THEN 12  WHEN 14 THEN 13  WHEN 15 THEN 4
            WHEN 16 THEN 10  WHEN 17 THEN 11  WHEN 18 THEN 9
            WHEN 19 THEN 9   ELSE 4
        END
        + (RANDOM() * 4 - 2)
    )::NUMERIC, 3)),
    CASE
        WHEN w.status = 'idle'        THEN ROUND((12 + RANDOM() * 8)::NUMERIC, 2)
        WHEN w.status = 'maintenance' THEN ROUND((6  + RANDOM() * 6)::NUMERIC, 2)
        ELSE ROUND((RANDOM() * 2)::NUMERIC, 2)
    END
FROM
    wells w
CROSS JOIN (
    SELECT
        generate_series(
            CURRENT_DATE - INTERVAL '89 days',
            CURRENT_DATE,
            INTERVAL '1 day'
        )::DATE AS day_date,
        ROW_NUMBER() OVER (ORDER BY generate_series) AS day_num
    FROM generate_series(1, 90)
) d;

INSERT INTO telemetry (well_id, recorded_at, pressure_bar, temperature_c, flow_rate_m3h, rpm)
SELECT
    w.well_id,
    t.ts,
    ROUND((
        (w.depth_m / 3500.0 * 150 + 50)
        + RANDOM() * 20 - 10
    )::NUMERIC, 3),
    ROUND((55 + RANDOM() * 30 + w.depth_m / 3500 * 15)::NUMERIC, 2),
    GREATEST(0, ROUND((
        CASE w.well_id
            WHEN  1 THEN 3.9  WHEN  2 THEN 3.6  WHEN  4 THEN 5.0
            WHEN  5 THEN 5.6  WHEN  7 THEN 3.2  WHEN  8 THEN 3.4
            WHEN  9 THEN 3.8  WHEN 11 THEN 4.6  WHEN 12 THEN 4.4
            ELSE 2.5
        END
        + RANDOM() * 1.0 - 0.5
    )::NUMERIC, 3)),
    ROUND((1450 + RANDOM() * 100 - 50)::NUMERIC, 2)
FROM
    wells w
CROSS JOIN (
    SELECT generate_series(
        NOW() - INTERVAL '59 days',
        NOW(),
        INTERVAL '6 hours'
    ) AS ts
) t
WHERE w.status = 'active'
  AND w.well_id IN (1, 2, 4, 5, 7, 8, 9, 11, 12, 13);

INSERT INTO well_targets (well_id, measured_at, pressure_bar, temperature_c, power_kw, pump_runtime_h, flow_rate_m3h)
SELECT
    w.well_id,
    t.ts,
    p_bar,
    temp_c,
    pwr_kw,
    runtime_h,
    GREATEST(0.5, ROUND((
        0.025 * p_bar
        - 0.015 * temp_c
        + 0.018 * pwr_kw
        + 0.08  * runtime_h
        + RANDOM() * 0.4 - 0.2
    )::NUMERIC, 3))
FROM
    wells w
CROSS JOIN (
    SELECT
        generate_series(
            NOW() - INTERVAL '20 days',
            NOW(),
            INTERVAL '1 hour'
        ) AS ts,
        ROUND((80 + RANDOM() * 120)::NUMERIC, 3) AS p_bar,
        ROUND((50 + RANDOM() * 40)::NUMERIC, 2)  AS temp_c,
        ROUND((15 + RANDOM() * 35)::NUMERIC, 3)  AS pwr_kw,
        ROUND((16 + RANDOM() * 8)::NUMERIC, 2)   AS runtime_h
    FROM generate_series(1, 500)
    LIMIT 500
) t
WHERE w.well_id IN (1, 4, 5, 11, 12)
LIMIT 500;

INSERT INTO pump_sensors (well_id, recorded_at, vibration_mm_s, temperature_c, current_a, rpm)
SELECT
    well_id,
    ts,
    ROUND(CASE
        WHEN ts BETWEEN failure_ts - INTERVAL '6 hours' AND failure_ts
            THEN 6 + RANDOM() * 6 + (EXTRACT(EPOCH FROM (ts - (failure_ts - INTERVAL '6 hours'))) / 21600.0) * 4
        WHEN ts BETWEEN failure_ts - INTERVAL '24 hours' AND failure_ts - INTERVAL '6 hours'
            THEN 3 + RANDOM() * 2
        ELSE 0.5 + RANDOM() * 2.0
    END::NUMERIC, 4),
    ROUND(CASE
        WHEN ts BETWEEN failure_ts - INTERVAL '6 hours' AND failure_ts
            THEN 85 + RANDOM() * 25
        WHEN ts BETWEEN failure_ts - INTERVAL '24 hours' AND failure_ts - INTERVAL '6 hours'
            THEN 75 + RANDOM() * 15
        ELSE 55 + RANDOM() * 20
    END::NUMERIC, 2),
    ROUND(CASE
        WHEN ts BETWEEN failure_ts - INTERVAL '6 hours' AND failure_ts
            THEN 42 + RANDOM() * 18
        ELSE 28 + RANDOM() * 10
    END::NUMERIC, 3),
    ROUND(CASE
        WHEN ts BETWEEN failure_ts - INTERVAL '6 hours' AND failure_ts
            THEN 1200 + RANDOM() * 300
        ELSE 1400 + RANDOM() * 100 - 50
    END::NUMERIC, 2)
FROM (
    SELECT
        w.well_id,
        t.ts,
        (NOW() - (w.well_id * 3 + 5) * INTERVAL '1 day') AS failure_ts
    FROM
        wells w
    CROSS JOIN (
        SELECT generate_series(
            NOW() - INTERVAL '29 days',
            NOW(),
            INTERVAL '2 hours'
        ) AS ts
    ) t
    WHERE w.well_id IN (1, 2, 4, 5, 7, 8, 11, 13, 16, 17)
    LIMIT 500
) sub;

INSERT INTO pump_failures (well_id, failed_at, failure_type, severity) VALUES
( 1, NOW() - INTERVAL '62 days', 'bearing',    'major'),
( 2, NOW() - INTERVAL '58 days', 'seal',       'minor'),
( 4, NOW() - INTERVAL '55 days', 'motor',      'critical'),
( 5, NOW() - INTERVAL '50 days', 'overheating','major'),
( 7, NOW() - INTERVAL '47 days', 'bearing',    'minor'),
( 8, NOW() - INTERVAL '44 days', 'seal',       'major'),
(11, NOW() - INTERVAL '41 days', 'motor',      'critical'),
(13, NOW() - INTERVAL '38 days', 'bearing',    'minor'),
(16, NOW() - INTERVAL '35 days', 'overheating','major'),
(17, NOW() - INTERVAL '32 days', 'seal',       'minor'),
( 1, NOW() - INTERVAL '29 days', 'bearing',    'major'),
( 2, NOW() - INTERVAL '26 days', 'motor',      'minor'),
( 4, NOW() - INTERVAL '23 days', 'bearing',    'critical'),
( 5, NOW() - INTERVAL '20 days', 'seal',       'minor'),
( 7, NOW() - INTERVAL '17 days', 'overheating','major'),
( 8, NOW() - INTERVAL '14 days', 'bearing',    'minor'),
(11, NOW() - INTERVAL '11 days', 'seal',       'major'),
(13, NOW() - INTERVAL '8  days', 'motor',      'critical'),
(16, NOW() - INTERVAL '5  days', 'bearing',    'minor'),
(17, NOW() - INTERVAL '2  days', 'overheating','major'),
( 9, NOW() - INTERVAL '60 days', 'seal',       'minor'),
(12, NOW() - INTERVAL '56 days', 'bearing',    'major'),
( 1, NOW() - INTERVAL '53 days', 'motor',      'minor'),
( 4, NOW() - INTERVAL '48 days', 'overheating','critical'),
( 7, NOW() - INTERVAL '43 days', 'bearing',    'major'),
( 9, NOW() - INTERVAL '39 days', 'seal',       'minor'),
(11, NOW() - INTERVAL '34 days', 'motor',      'critical'),
(12, NOW() - INTERVAL '30 days', 'bearing',    'minor'),
(13, NOW() - INTERVAL '25 days', 'overheating','major'),
(16, NOW() - INTERVAL '21 days', 'seal',       'minor'),
( 2, NOW() - INTERVAL '18 days', 'bearing',    'major'),
( 5, NOW() - INTERVAL '15 days', 'motor',      'minor'),
( 8, NOW() - INTERVAL '12 days', 'seal',       'major'),
(17, NOW() - INTERVAL '9  days', 'bearing',    'critical'),
( 1, NOW() - INTERVAL '6  days', 'overheating','minor'),
( 4, NOW() - INTERVAL '3  days', 'motor',      'major'),
( 7, NOW() - INTERVAL '1  day',  'bearing',    'minor'),
( 9, NOW() - INTERVAL '72 hours','seal',        'major'),
(12, NOW() - INTERVAL '48 hours','motor',       'critical'),
(13, NOW() - INTERVAL '24 hours','overheating', 'minor');

INSERT INTO deliveries (route_id, driver_id, origin, destination, distance_km, volume_t, cost_rub, planned_date, actual_date, weather, road_type)
SELECT
    'RT-' || LPAD(((ROW_NUMBER() OVER ()) % 20 + 1)::TEXT, 3, '0'),
    (RANDOM() * 14 + 1)::INTEGER,
    origins.origin,
    destinations.dest,
    ROUND((100 + RANDOM() * 900)::NUMERIC, 2),
    ROUND((5 + RANDOM() * 45)::NUMERIC, 3),
    ROUND((
        (100 + RANDOM() * 900)  -- distance (повторяется)
        * CASE road
            WHEN 'highway' THEN 85  + RANDOM() * 20
            WHEN 'gravel'  THEN 110 + RANDOM() * 25
            WHEN 'offroad' THEN 150 + RANDOM() * 40
        END
    )::NUMERIC, 2),
    planned_d,
    planned_d + GREATEST(0,
        CASE weather_cond
            WHEN 'clear' THEN (RANDOM() * 1.5)::INTEGER
            WHEN 'rain'  THEN (RANDOM() * 2 + 0.5)::INTEGER
            WHEN 'fog'   THEN (RANDOM() * 2 + 1)::INTEGER
            WHEN 'snow'  THEN (RANDOM() * 4 + 2)::INTEGER
        END
        +
        CASE road
            WHEN 'highway' THEN 0
            WHEN 'gravel'  THEN (RANDOM() * 1)::INTEGER
            WHEN 'offroad' THEN (RANDOM() * 2 + 1)::INTEGER
        END
    )::INTEGER,
    weather_cond,
    road
FROM (
    SELECT
        generate_series AS gs,
        (CURRENT_DATE - (RANDOM() * 180)::INTEGER) AS planned_d,
        (ARRAY['clear','clear','clear','rain','rain','fog','snow','snow'])[
            (RANDOM() * 7 + 1)::INTEGER
        ] AS weather_cond,
        (ARRAY['highway','highway','gravel','gravel','offroad'])[
            (RANDOM() * 4 + 1)::INTEGER
        ] AS road
    FROM generate_series(1, 300)
) base
CROSS JOIN (VALUES
    ('Нижневартовск'), ('Сургут'), ('Ханты-Мансийск'), ('Нефтеюганск'), ('Когалым')
) origins(origin)
CROSS JOIN (VALUES
    ('Тюмень'), ('Омск'), ('Екатеринбург'), ('Пермь'), ('Уфа')
) destinations(dest)
LIMIT 300;
