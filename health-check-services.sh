#!/bin/bash

# Script to verify all service connections and health
# This can be run anytime after services are started

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Service Connectivity and Health Check ===${NC}"
echo ""

# Load variables from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Function to test connectivity
test_connection() {
    local name=$1
    local host=$2
    local port=$3
    local timeout=${4:-5}
    
    echo -n "  ✓ Testing $name ($host:$port)... "
    
    if docker exec frappe-develop-blueprint_backend_1 python3 -c "import socket; socket.create_connection(('$host', $port), timeout=$timeout)" 2>/dev/null; then
        echo -e "${GREEN}Connected${NC}"
        return 0
    else
        echo -e "${RED}Failed${NC}"
        return 1
    fi
}

# Function to check container status
check_container() {
    local container=$1
    local expected_state=$2
    
    echo -n "  ✓ Checking $container... "
    
    local status=$(docker-compose ps "$container" 2>/dev/null | tail -1 | awk '{print $NF}' || echo "unknown")
    
    if [[ "$status" == *"$expected_state"* ]]; then
        echo -e "${GREEN}$status${NC}"
        return 0
    else
        echo -e "${RED}$status${NC}"
        return 1
    fi
}

# Get service statuses
echo -e "${BLUE}1. Service Status${NC}"
docker-compose ps
echo ""

# Test database connectivity
echo -e "${BLUE}2. Database Connectivity${NC}"
db_ok=true
test_connection "MariaDB" "${DB_HOST:-mariadb}" "${DB_PORT:-3306}" || db_ok=false
echo ""

# Test Redis connectivity
echo -e "${BLUE}3. Redis Connectivity${NC}"
redis_ok=true
test_connection "Redis Cache" "${REDIS_CACHE%:*}" "${REDIS_CACHE##*:}" || redis_ok=false
test_connection "Redis Queue" "${REDIS_QUEUE%:*}" "${REDIS_QUEUE##*:}" || redis_ok=false
echo ""

# Check container health
echo -e "${BLUE}4. Container Health Checks${NC}"
health_ok=true
check_container "frappe-develop-blueprint_mariadb_1" "healthy" || health_ok=false
check_container "frappe-develop-blueprint_redis-cache_1" "healthy" || health_ok=false
check_container "frappe-develop-blueprint_redis-queue_1" "healthy" || health_ok=false
check_container "frappe-develop-blueprint_backend_1" "Up" || health_ok=false
echo ""

# Database verification
echo -e "${BLUE}5. Database Access Verification${NC}"
echo -n "  ✓ Testing database user '$DB_USER'... "
if docker exec frappe-develop-blueprint_backend_1 mysql -h"${DB_HOST:-mariadb}" -P"${DB_PORT:-3306}" -u"${DB_USER:-frappe}" -p"${DB_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}Failed${NC}"
    echo -e "${YELLOW}    Troubleshooting:${NC}"
    echo -e "${YELLOW}    - Check DB_PASSWORD in .env${NC}"
    echo -e "${YELLOW}    - Run: docker logs frappe-develop-blueprint_mariadb_1${NC}"
    db_ok=false
fi
echo ""

# Backend logs check
echo -e "${BLUE}6. Backend Logs (Last 20 lines)${NC}"
echo "---"
docker logs frappe-develop-blueprint_backend_1 2>&1 | tail -20
echo "---"
echo ""

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
if [ "$db_ok" = true ] && [ "$redis_ok" = true ] && [ "$health_ok" = true ]; then
    echo -e "${GREEN}✅ All services are healthy and connected!${NC}"
    echo ""
    echo -e "${GREEN}Configuration:${NC}"
    echo "  Site Name: ${SITE_NAME}"
    echo "  Database: ${DB_NAME} @ ${DB_HOST}:${DB_PORT}"
    echo "  Database User: ${DB_USER}"
    echo "  Admin Password: ${ADMIN_PASSWORD}"
    echo ""
    echo -e "${GREEN}Access Information:${NC}"
    echo "  Backend: http://localhost:8000"
    echo "  Database Port: ${DB_PORT}"
    exit 0
else
    echo -e "${RED}❌ Some services are not healthy. Check the logs above.${NC}"
    echo ""
    echo -e "${YELLOW}Helpful commands:${NC}"
    echo "  docker-compose logs -f backend           # Follow backend logs"
    echo "  docker-compose logs -f mariadb           # Follow database logs"
    echo "  docker-compose logs -f redis-cache       # Follow Redis logs"
    echo "  docker exec frappe-develop-blueprint_backend_1 bash  # Access backend shell"
    exit 1
fi
