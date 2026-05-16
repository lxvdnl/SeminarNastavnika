import os

SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "superset_secret_oilfield_2024")

SQLALCHEMY_DATABASE_URI = "sqlite:////app/superset_home/superset.db"

WTF_CSRF_ENABLED = False

HTTP_HEADERS = {}

FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "DASHBOARD_NATIVE_FILTERS": True,
}

ENABLE_TIME_ROTATE = False
