set -e

echo "=== Superset: running DB upgrade ==="
superset db upgrade

echo "=== Superset: creating admin user ==="
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@oilfield.com \
  --password admin123 \
  2>/dev/null || echo "Admin user already exists, skipping."

echo "=== Superset: initializing roles and permissions ==="
superset init

echo "=== Superset: starting server ==="
gunicorn \
  --bind 0.0.0.0:8088 \
  --workers 2 \
  --worker-class gthread \
  --threads 20 \
  --timeout 120 \
  --limit-request-line 0 \
  --limit-request-field_size 0 \
  "superset.app:create_app()"
