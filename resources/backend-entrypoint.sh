#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Environment variables with default values
SITE_NAME="${SITE_NAME:-dpe.erp.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-admin}"

echo "🚀 Starting site configuration..."

# Wait for database to be ready
echo "⏳ Waiting for MariaDB to be available..."
until mysql -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    echo "MariaDB is not ready - waiting..."
    sleep 2
done
echo "✅ MariaDB is ready"

# Wait for Redis to be ready
echo "⏳ Waiting for Redis to be available..."
until redis-cli -h "${REDIS_CACHE}" ping >/dev/null 2>&1; do
    echo "Redis is not ready - waiting..."
    sleep 2
done
echo "✅ Redis is ready"

# Check if site already exists
if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "📦 Creating new site: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --admin-password "${ADMIN_PASSWORD}" \
        --db-root-password "${DB_ROOT_PASSWORD}" \
        --db-host "${DB_HOST}" \
        --db-name "${DB_NAME:-_$(echo ${SITE_NAME} | tr '.' '_')}" \
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

# Start server using restart.py
echo "🚀 Starting server with restart.py..."
cd /home/frappe/frappe-bench
exec /home/frappe/frappe-bench/env/bin/python restart.py
