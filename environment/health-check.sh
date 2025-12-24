#!/bin/bash
set -e

# Script de health check para monitorear el estado del deployment
# Uso: ./health-check.sh

SITE_URL=${SITE_URL:-"http://localhost:8080"}
SITE_NAME=${FRAPPE_SITE_NAME:-"dev.example.com"}

echo "🏥 Iniciando health check..."

# 1. Verificar que los contenedores estén corriendo
echo ""
echo "📦 Estado de los contenedores:"
docker compose ps

# 2. Verificar conectividad HTTP
echo ""
echo "🌐 Verificando conectividad HTTP..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $SITE_URL)
if [ $HTTP_STATUS -eq 200 ] || [ $HTTP_STATUS -eq 302 ]; then
    echo "✅ HTTP Status: $HTTP_STATUS (OK)"
else
    echo "❌ HTTP Status: $HTTP_STATUS (FAILED)"
    exit 1
fi

# 3. Verificar API
echo ""
echo "🔌 Verificando API..."
API_RESPONSE=$(curl -s $SITE_URL/api/method/ping)
if echo $API_RESPONSE | grep -q "pong"; then
    echo "✅ API: Respondiendo correctamente"
else
    echo "❌ API: No responde correctamente"
    echo "Respuesta: $API_RESPONSE"
fi

# 4. Verificar database
echo ""
echo "🗄️ Verificando conexión a base de datos..."
DB_CHECK=$(docker compose exec -T backend bench --site $SITE_NAME doctor 2>&1 | grep -i "database" || true)
echo "$DB_CHECK"

# 5. Verificar workers de queue
echo ""
echo "👷 Verificando workers de queue..."
WORKERS=$(docker compose ps | grep -E "queue|scheduler" | grep "Up" | wc -l)
if [ $WORKERS -ge 3 ]; then
    echo "✅ Workers: $WORKERS activos"
else
    echo "⚠️ Workers: Solo $WORKERS activos (esperados: 3)"
fi

# 6. Uso de recursos
echo ""
echo "💻 Uso de recursos:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# 7. Logs recientes de errores
echo ""
echo "📋 Últimos errores en logs (si hay):"
docker compose logs --tail=20 --since=5m | grep -i "error" | tail -10 || echo "No se encontraron errores recientes"

echo ""
echo "✅ Health check completado!"
