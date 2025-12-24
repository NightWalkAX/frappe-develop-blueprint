#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Variables de entorno con valores por defecto
SITE_NAME="${SITE_NAME:-dpe.erp.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-admin}"
CUSTOM_APP_NAME="${CUSTOM_APP_NAME:-travel_agency_erp}"

echo "🚀 Iniciando configuración del sitio..."

# Esperar a que la base de datos esté lista
echo "⏳ Esperando a que MariaDB esté disponible..."
until mysql -h"${DB_HOST}" -uroot -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
    echo "MariaDB no está listo - esperando..."
    sleep 2
done
echo "✅ MariaDB está listo"

# Esperar a que Redis esté listo
echo "⏳ Esperando a que Redis esté disponible..."
until redis-cli -h "${REDIS_CACHE}" ping >/dev/null 2>&1; do
    echo "Redis no está listo - esperando..."
    sleep 2
done
echo "✅ Redis está listo"

# Verificar si el sitio ya existe
if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "📦 Creando nuevo sitio: ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --admin-password "${ADMIN_PASSWORD}" \
        --db-root-password "${DB_ROOT_PASSWORD}" \
        --db-host "${DB_HOST}" \
        --db-name "${DB_NAME:-_$(echo ${SITE_NAME} | tr '.' '_')}" \
        --no-mariadb-socket \
        --force
    
    echo "✅ Sitio creado exitosamente"
    
    # Instalar la app personalizada
    if [ -d "apps/${CUSTOM_APP_NAME}" ]; then
        echo "📱 Instalando app: ${CUSTOM_APP_NAME}"
        bench --site "${SITE_NAME}" install-app "${CUSTOM_APP_NAME}"
        echo "✅ App instalada exitosamente"
    else
        echo "⚠️  App ${CUSTOM_APP_NAME} no encontrada en apps/"
    fi
    
    # Habilitar modo desarrollador
    echo "🔧 Habilitando modo desarrollador"
    bench --site "${SITE_NAME}" set-config developer_mode 1
    
    # Configurar el sitio como currentsite
    echo "${SITE_NAME}" > sites/currentsite.txt
    
    echo "✅ Configuración completada"
else
    echo "ℹ️  El sitio ${SITE_NAME} ya existe, omitiendo creación"
    echo "${SITE_NAME}" > sites/currentsite.txt
fi

# Ejecutar migraciones si es necesario
echo "🔄 Ejecutando migraciones..."
bench --site "${SITE_NAME}" migrate || echo "⚠️  Migraciones completadas con advertencias"

# Limpiar cache
echo "🧹 Limpiando cache..."
bench --site "${SITE_NAME}" clear-cache

# Extraer bench.zip si existe en la app personalizada
BENCH_ZIP_PATH="apps/${CUSTOM_APP_NAME}/bench.zip"
if [ -f "${BENCH_ZIP_PATH}" ]; then
    echo "📦 Encontrado bench.zip, extrayendo a la raíz del bench..."
    unzip -o "${BENCH_ZIP_PATH}" -d /home/frappe/frappe-bench/
    echo "✅ Contenidos extraídos exitosamente"
else
    echo "ℹ️  bench.zip no encontrado en ${BENCH_ZIP_PATH}, omitiendo extracción"
fi

echo "🎉 Sitio listo: ${SITE_NAME}"
echo "👤 Usuario: Administrator"
echo "🔑 Password: ${ADMIN_PASSWORD}"

# Iniciar el servidor usando restart.py
echo "🚀 Iniciando servidor con restart.py..."
cd /home/frappe/frappe-bench
exec /home/frappe/frappe-bench/env/bin/python restart.py
