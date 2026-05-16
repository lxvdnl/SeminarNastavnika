# Big Data & ML Pipeline

## Запуск

```bash
docker compose up --build
```

## Сервисы

| Сервис     | URL                    | Доступ                         |
|------------|------------------------|--------------------------------|
| JupyterLab | http://localhost:8888  | token: `oilfield`              |
| MinIO      | http://localhost:9001  | `minioadmin` / `minioadmin123` |
| Superset   | http://localhost:8088  | `admin` / `admin123`           |
| PostgreSQL | `localhost:5432`       | `oilfield` / `oilfield123`     |

## Задания

1. **Аналитика добычи** — витрины по скважинам, суточная добыча, heatmap давление/дебит
2. **Прогноз дебита** — LinearRegression и RandomForest на данных телеметрии
3. **Аномалии** — Z-score и Isolation Forest на показаниях насосов
4. **Логистика** — анализ задержек, cost/km, KPI водителей

## Где смотреть результаты

Все задания выполнены в Jupyter ноутбуках

- `notebooks/01_production_analytics.ipynb` — задание 1
- `notebooks/02_ml_prediction.ipynb` — задание 2
- `notebooks/03_anomaly_detection.ipynb` — задание 3
- `notebooks/04_logistics.ipynb` — задание 4

Аналитические витрины сохранены в PostgreSQL: `analytics_well_kpi`, `analytics_daily_production`, `analytics_predictions`, `analytics_anomalies`, `analytics_logistics`.