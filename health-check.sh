#!/bin/bash
set -e

# Health check script to monitor deployment status
# Usage: ./health-check.sh

SITE_URL=${SITE_URL:-"http://localhost:8080"}
SITE_NAME=${FRAPPE_SITE_NAME:-"dev.example.com"}

echo "🏥 Starting health check..."

# 1. Verificar que los contenedores estén corriendo
echo ""
echo "📦 Estado de los contenedores:"
docker compose ps

# 2. Check HTTP connectivity
echo ""
echo "🌐 Checking HTTP connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $SITE_URL)
if [ $HTTP_STATUS -eq 200 ] || [ $HTTP_STATUS -eq 302 ]; then
    echo "✅ HTTP Status: $HTTP_STATUS (OK)"
else
    echo "❌ HTTP Status: $HTTP_STATUS (FAILED)"
    exit 1
fi

# 3. Check API
echo ""
echo "🔌 Checking API..."
API_RESPONSE=$(curl -s $SITE_URL/api/method/ping)
if echo $API_RESPONSE | grep -q "pong"; then
    echo "✅ API: Responding correctly"
else
    echo "❌ API: Not responding correctly"
    echo "Response: $API_RESPONSE"
fi

# 4. Check database
echo ""
echo "🗄️ Checking database connection..."
DB_CHECK=$(docker compose exec -T backend bench --site $SITE_NAME doctor 2>&1 | grep -i "database" || true)
echo "$DB_CHECK"

# 5. Check queue workers
echo ""
echo "👷 Checking queue workers..."
WORKERS=$(docker compose ps | grep -E "queue|scheduler" | grep "Up" | wc -l)
if [ $WORKERS -ge 3 ]; then
    echo "✅ Workers: $WORKERS active"
else
    echo "⚠️ Workers: Only $WORKERS active (expected: 3)"
fi

# 6. Resource usage
echo ""
echo "💻 Resource usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# 7. Recent error logs
echo ""
echo "📋 Latest errors in logs (if any):"
docker compose logs --tail=20 --since=5m | grep -i "error" | tail -10 || echo "No recent errors found"

echo ""
echo "✅ Health check completed!"
