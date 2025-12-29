#!/bin/bash

# Script to build and compose the custom image and services
# Reads variables from .env file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Port range configuration
PORT_RANGE_START=8000
PORT_RANGE_END=8099

echo -e "${GREEN}=== Build and Compose Script ===${NC}"

# Check if user is in docker group (don't auto-add for security)
if ! groups $USER | grep -q '\bdocker\b'; then
    echo -e "${YELLOW}Warning: User '$USER' is not in the docker group.${NC}"
    echo -e "${YELLOW}To add yourself to the docker group, run:${NC}"
    echo -e "${YELLOW}  sudo usermod -aG docker \$USER${NC}"
    echo -e "${YELLOW}Then log out and log back in for changes to take effect.${NC}"
    read -p "Continue anyway using sudo for docker commands? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted. Please add user to docker group first.${NC}"
        exit 1
    fi
    DOCKER_CMD="sudo docker"
    COMPOSE_CMD="sudo docker-compose"
else
    DOCKER_CMD="docker"
    COMPOSE_CMD="docker-compose"
fi

# Function to check if a port is available
is_port_available() {
    local port=$1
    if ! ss -tuln 2>/dev/null | grep -q ":${port} " && \
       ! netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0  # Port is available
    fi
    return 1  # Port is in use
}

# Function to find an available port in the range
find_available_port() {
    local preferred_port=$1
    
    # Try preferred port first if specified and in range
    if [ -n "$preferred_port" ] && [ "$preferred_port" -ge "$PORT_RANGE_START" ] && [ "$preferred_port" -le "$PORT_RANGE_END" ]; then
        if is_port_available "$preferred_port"; then
            echo "$preferred_port"
            return 0
        fi
        echo -e "${YELLOW}Puerto preferido $preferred_port no disponible, buscando alternativa...${NC}" >&2
    fi
    
    # Search for available port in range
    for port in $(seq $PORT_RANGE_START $PORT_RANGE_END); do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done
    
    echo -e "${RED}Error: No se encontraron puertos disponibles en el rango $PORT_RANGE_START-$PORT_RANGE_END${NC}" >&2
    return 1
}

# Verify that .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure the required variables${NC}"
    exit 1
fi

# Load variables from .env safely (validate each line)
echo -e "${GREEN}Loading variables from .env...${NC}"
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    # Remove leading/trailing whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    # Validate key format (alphanumeric and underscore only)
    if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        export "$key=$value"
    else
        echo -e "${YELLOW}Warning: Skipping invalid variable name: $key${NC}"
    fi
done < .env

# Security validation function
validate_password_strength() {
    local password=$1
    local name=$2
    local min_length=${3:-12}
    
    if [ -z "$password" ]; then
        return 0  # Empty is OK for optional passwords
    fi
    
    # Check for default/weak passwords
    if [[ "$password" == "admin" || "$password" == "password" || "$password" == "frappe_password" || "$password" =~ ^CHANGE_THIS ]]; then
        echo -e "${RED}⚠️  SECURITY ERROR: $name contains a weak/default password!${NC}"
        echo -e "${RED}   Please set a strong password (min $min_length chars with mixed case, numbers, symbols)${NC}"
        return 1
    fi
    
    # Check minimum length
    if [ ${#password} -lt $min_length ]; then
        echo -e "${YELLOW}⚠️  WARNING: $name is shorter than recommended ($min_length characters)${NC}"
    fi
    
    return 0
}

# Validate passwords for production
echo -e "${GREEN}Validating security configuration...${NC}"
validation_failed=false

if ! validate_password_strength "$ADMIN_PASSWORD" "ADMIN_PASSWORD" 12; then
    validation_failed=true
fi

if ! validate_password_strength "$DB_PASSWORD" "DB_PASSWORD" 16; then
    validation_failed=true
fi

if [ "$validation_failed" = true ]; then
    echo -e "${RED}Security validation failed. Please update your .env file.${NC}"
    read -p "Continue anyway? This is NOT recommended for production! (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 1
    fi
    echo -e "${YELLOW}Proceeding with weak passwords - NOT RECOMMENDED FOR PRODUCTION${NC}"
fi

# Verify required variables
if [ -z "$CUSTOM_APPS" ]; then
    echo -e "${YELLOW}Warning: CUSTOM_APPS variable is not defined in .env${NC}"
    echo -e "${YELLOW}No custom apps will be installed. Only Frappe will be available.${NC}"
fi

# Default values
FRAPPE_BRANCH=${FRAPPE_BRANCH:-version-15}
PYTHON_VERSION=${PYTHON_VERSION:-3.11.6}
CUSTOM_IMAGE=${CUSTOM_IMAGE:-frappe-custom}
CUSTOM_TAG=${CUSTOM_TAG:-latest}

# Find available port dynamically
echo -e "${GREEN}Buscando puerto disponible en rango $PORT_RANGE_START-$PORT_RANGE_END...${NC}"
FRAPPE_PORT=$(find_available_port "${FRAPPE_PORT:-}")

if [ -z "$FRAPPE_PORT" ]; then
    echo -e "${RED}Error: No se pudo encontrar un puerto disponible${NC}"
    exit 1
fi

# Export the port so it's available to docker-compose
export FRAPPE_PORT

echo -e "${GREEN}✓ Puerto disponible encontrado: $FRAPPE_PORT${NC}"

echo -e "${GREEN}Configuration:${NC}"
echo "  CUSTOM_APPS: $CUSTOM_APPS"
echo "  FRAPPE_BRANCH: $FRAPPE_BRANCH"
echo "  PYTHON_VERSION: $PYTHON_VERSION"
echo "  IMAGE: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
echo "  FRAPPE_PORT: $FRAPPE_PORT (auto-detected)"
if [ -n "$GITHUB_TOKEN" ]; then
    echo "  GITHUB_TOKEN: ******* (configured)"
else
    echo "  GITHUB_TOKEN: (not configured - may fail on private repositories)"
fi

# Build the image
echo -e "${GREEN}Starting image build...${NC}"

# Use BuildKit for secure secret handling (GITHUB_TOKEN won't be stored in image layers)
export DOCKER_BUILDKIT=1

# Create temporary secret file for GitHub token
GITHUB_TOKEN_FILE=""
BUILD_SECRET_ARG=""
if [ -n "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN_FILE=$(mktemp)
    echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_FILE"
    chmod 600 "$GITHUB_TOKEN_FILE"
    BUILD_SECRET_ARG="--secret id=github_token,src=$GITHUB_TOKEN_FILE"
    echo -e "${GREEN}Using BuildKit secrets for secure token handling${NC}"
fi

# Cleanup function
cleanup_secrets() {
    if [ -n "$GITHUB_TOKEN_FILE" ] && [ -f "$GITHUB_TOKEN_FILE" ]; then
        rm -f "$GITHUB_TOKEN_FILE"
    fi
}
trap cleanup_secrets EXIT

$DOCKER_CMD build \
    $BUILD_SECRET_ARG \
    --build-arg CUSTOM_APPS="$CUSTOM_APPS" \
    --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
    --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
    -t ${CUSTOM_IMAGE}:${CUSTOM_TAG} \
    -f images/production/Containerfile \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully: ${CUSTOM_IMAGE}:${CUSTOM_TAG}${NC}"
else
    echo -e "${RED}✗ Error building image${NC}"
    exit 1
fi

# Compose and start services
echo -e "${GREEN}Starting services with docker-compose...${NC}"
$COMPOSE_CMD -f compose.yaml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Services started successfully${NC}"
    echo -e "${YELLOW}Waiting for services to initialize (30 seconds)...${NC}"
    sleep 30
    echo -e "${GREEN}Services status:${NC}"
    $COMPOSE_CMD -f compose.yaml ps
    
    # Verify service connectivity
    echo -e "${YELLOW}Verifying service connectivity...${NC}"
    
    # Function to test connectivity
    test_service_connection() {
        local service=$1
        local host=$2
        local port=$3
        echo -n "  Testing $service ($host:$port)... "
        
        if docker exec frappe-develop-blueprint_backend_1 python3 -c "import socket; socket.create_connection(('$host', $port), timeout=5)" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            return 1
        fi
    }
    
    # Test connections
    all_ok=true
    test_service_connection "MariaDB" "mariadb" "3306" || all_ok=false
    test_service_connection "Redis Cache" "redis-cache" "6379" || all_ok=false
    test_service_connection "Redis Queue" "redis-queue" "6379" || all_ok=false
    
    # Check if backend is running and healthy
    echo -n "  Checking Backend health... "
    backend_status=$(docker-compose ps frappe-develop-blueprint_backend_1 2>/dev/null | grep -i "up\|running" | wc -l)
    if [ "$backend_status" -gt 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        all_ok=false
    fi
    
    # Check MariaDB health
    echo -n "  Checking MariaDB health... "
    db_health=$(docker-compose ps frappe-develop-blueprint_mariadb_1 2>/dev/null | grep "healthy" | wc -l)
    if [ "$db_health" -gt 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        all_ok=false
    fi
    
    # Check Redis health
    echo -n "  Checking Redis Cache health... "
    redis_health=$(docker-compose ps frappe-develop-blueprint_redis-cache_1 2>/dev/null | grep "healthy" | wc -l)
    if [ "$redis_health" -gt 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        all_ok=false
    fi
    
    # Final result
    echo ""
    if [ "$all_ok" = true ]; then
        echo -e "${GREEN}✅ All services are running and connected successfully!${NC}"
        echo ""
        echo -e "${GREEN}Environment Information:${NC}"
        echo "  Database Host: mariadb:3306"
        echo "  Database Name: ${DB_NAME}"
        echo "  Database User: ${DB_USER}"
        echo "  Site Name: ${SITE_NAME}"
        echo "  Admin Email: Administrator"
        echo "  Admin Password: ${ADMIN_PASSWORD}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}🌐 Access your ERP at: ${YELLOW}http://localhost:${FRAPPE_PORT}${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    else
        echo -e "${YELLOW}⚠️  Some services may not be fully initialized yet.${NC}"
        echo -e "${YELLOW}Check logs with: docker-compose logs -f${NC}"
        echo ""
        echo -e "${YELLOW}When ready, access your ERP at: http://localhost:${FRAPPE_PORT}${NC}"
    fi
else
    echo -e "${RED}✗ Error starting services${NC}"
    exit 1
fi
