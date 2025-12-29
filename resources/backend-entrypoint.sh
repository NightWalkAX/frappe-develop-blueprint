#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Environment variables with default values
SITE_NAME="${SITE_NAME:-erp.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_USER="${DB_ROOT_USER:-root}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-frappe_password}"
DB_NAME="${DB_NAME:-frappe_db}"
REDIS_CACHE="${REDIS_CACHE:-redis-cache:6379}"

echo "🚀 Starting site configuration..."

# Copy bench_files contents to bench root if /bench_files directory exists
echo "🔍 Checking for bench_files contents..."
if [ -d "/bench_files" ] && [ "$(ls -A /bench_files 2>/dev/null)" ]; then
  echo "📦 Found bench_files directory, copying contents to bench root..."
  cp -rv /bench_files/* /home/frappe/frappe-bench/ 2>/dev/null || true
  cp -rv /bench_files/.* /home/frappe/frappe-bench/ 2>/dev/null || true
  echo "✅ bench_files contents copied successfully"
else
  echo "ℹ️  No bench_files directory found or it's empty"
fi

# Wait for database to be ready
echo "⏳ Waiting for MariaDB to be available..."
until mysql -h"${DB_HOST}" -P"${DB_PORT}" -u"${DB_ROOT_USER}" -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    echo "MariaDB is not ready - waiting..."
    sleep 2
done
echo "✅ MariaDB is ready"

# Wait for Redis to be ready
echo "⏳ Waiting for Redis to be available..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if python3 -c "import socket; socket.create_connection(('${REDIS_CACHE%:*}', ${REDIS_CACHE##*:}), timeout=2)" 2>/dev/null; then
        echo "✅ Redis is ready"
        break
    fi
    attempt=$((attempt + 1))
    echo "Redis is not ready - waiting... ($attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️  Redis connection timeout - continuing anyway"
fi

# Check if site already exists
if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "📦 Creating new site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --admin-password "${ADMIN_PASSWORD}" \
        --db-host "${DB_HOST}" \
        --db-port "${DB_PORT}" \
        --db-root-username "${DB_ROOT_USER}" \
        --db-root-password "${DB_ROOT_PASSWORD}" \
        --no-mariadb-socket \
        --force
    
    echo "✅ Site created successfully"
    
    # Install custom apps from list
    if [ -f "/home/frappe/frappe-bench/.custom_apps_list" ]; then
        apps_list=$(cat /home/frappe/frappe-bench/.custom_apps_list)
        echo "📱 Installing custom apps from build list..."
        echo "$apps_list" | tr ',' '\n' | while IFS=':' read -r repo branch; do
            if [ -n "$repo" ]; then
                app_name=$(basename "$repo" .git)
                if [ -d "apps/$app_name" ]; then
                    echo "📱 Installing app: $app_name"
                    bench --site "${SITE_NAME}" install-app "$app_name"
                    echo "✅ App $app_name installed successfully"
                else
                    echo "⚠️  App $app_name not found in apps/"
                fi
            fi
        done
    else
        echo "ℹ️  No custom apps list found, skipping app installation"
    fi
    
    # Enable developer mode
    echo "🔧 Enabling developer mode"
    bench --site "${SITE_NAME}" set-config developer_mode 1
    
    # Set site as currentsite
    echo "${SITE_NAME}" > sites/currentsite.txt
    
    echo "✅ Configuration completed"
else
    echo "ℹ️  Site ${SITE_NAME} already exists, skipping creation"
    echo "${SITE_NAME}" > sites/currentsite.txt
fi

# Run migrations if needed
echo "🔄 Running migrations..."
bench --site "${SITE_NAME}" migrate || echo "⚠️  Migrations completed with warnings"

# Clear cache
echo "🧹 Clearing cache..."
bench --site "${SITE_NAME}" clear-cache

echo "🎉 Site ready: ${SITE_NAME}"
echo "👤 User: Administrator"
echo "🔑 Password: ${ADMIN_PASSWORD}"

# Start Frappe server
FRAPPE_PORT="${FRAPPE_PORT:-8000}"
echo "🚀 Starting Frappe server on port ${FRAPPE_PORT}..."
cd /home/frappe/frappe-bench
exec bench --site "${SITE_NAME}" serve --port "${FRAPPE_PORT}"
