#!/bin/bash
set -e

# Script de rollback para deployments
# Uso: ./rollback.sh <version-tag>

if [ -z "$1" ]; then
    echo "❌ Error: Debe especificar un tag de versión"
    echo "Uso: $0 <version-tag>"
    echo ""
    echo "Versiones disponibles:"
    docker images | grep travel-agency-erp | awk '{print $2}'
    exit 1
fi

VERSION_TAG=$1
SITE_NAME=${FRAPPE_SITE_NAME:-"dev.example.com"}

echo "🔄 Iniciando rollback a versión: $VERSION_TAG"

# Backup antes del rollback
echo "📦 Creando backup de seguridad..."
docker compose exec -T backend bench --site $SITE_NAME backup --with-files

# Actualizar el tag en el .env
echo "📝 Actualizando .env..."
sed -i "s/CUSTOM_TAG=.*/CUSTOM_TAG=$VERSION_TAG/" .env

# Pull de la imagen específica
echo "📥 Obteniendo imagen $VERSION_TAG..."
docker compose pull

# Reiniciar servicios
echo "♻️ Reiniciando servicios..."
docker compose down
docker compose up -d

# Verificar
echo "⏳ Esperando que los servicios estén listos..."
sleep 15

echo "🧪 Verificando estado de los servicios..."
docker compose ps

echo "✅ Rollback completado!"
echo "💡 Si hay problemas, los backups están en:"
docker compose exec -T backend bench --site $SITE_NAME list-backups | tail -5
