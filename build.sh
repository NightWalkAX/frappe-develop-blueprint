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

sudo usermod -aG docker $USER

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

# Function to check and setup SSH keys for GitHub
check_and_setup_ssh() {
    local ssh_key_path=""
    local ssh_pub_key=""
    
    echo -e "${GREEN}Verificando configuración de SSH para GitHub...${NC}"
    
    # Check if SSH_PRIVATE_KEY is set in environment
    if [ -n "$SSH_PRIVATE_KEY" ]; then
        if [ -f "$SSH_PRIVATE_KEY" ]; then
            echo -e "${GREEN}✓ SSH_PRIVATE_KEY encontrada: $SSH_PRIVATE_KEY${NC}"
            ssh_key_path="$SSH_PRIVATE_KEY"
        else
            echo -e "${YELLOW}⚠️  SSH_PRIVATE_KEY definida pero el archivo no existe: $SSH_PRIVATE_KEY${NC}"
        fi
    fi
    
    # If no valid key found, check default locations
    if [ -z "$ssh_key_path" ]; then
        for key in ~/.ssh/id_ed25519 ~/.ssh/id_rsa ~/.ssh/id_ecdsa; do
            if [ -f "$key" ]; then
                ssh_key_path="$key"
                echo -e "${GREEN}✓ Clave SSH encontrada: $ssh_key_path${NC}"
                break
            fi
        done
    fi
    
    # If still no key, offer to generate one
    if [ -z "$ssh_key_path" ]; then
        echo -e "${YELLOW}⚠️  No se encontró ninguna clave SSH configurada${NC}"
        echo -e "${YELLOW}Para clonar repositorios privados necesitas una clave SSH${NC}"
        echo ""
        read -p "¿Deseas generar una nueva clave SSH ahora? (s/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            
            echo -e "${GREEN}Generando nueva clave SSH Ed25519...${NC}"
            read -p "Ingresa tu email de GitHub: " github_email
            
            ssh-keygen -t ed25519 -C "$github_email" -f ~/.ssh/id_ed25519 -N ""
            
            if [ $? -eq 0 ]; then
                ssh_key_path="$HOME/.ssh/id_ed25519"
                echo -e "${GREEN}✓ Clave SSH generada exitosamente${NC}"
                
                # Start ssh-agent and add key
                eval "$(ssh-agent -s)" > /dev/null 2>&1
                ssh-add "$ssh_key_path" 2>/dev/null
            else
                echo -e "${RED}✗ Error al generar la clave SSH${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}⚠️  Continuando sin clave SSH - puede fallar con repositorios privados${NC}"
            return 0
        fi
    fi
    
    # Get public key
    if [ -f "${ssh_key_path}.pub" ]; then
        ssh_pub_key=$(cat "${ssh_key_path}.pub")
    fi
    
    # Test GitHub SSH connection
    echo -e "${GREEN}Probando conexión SSH a GitHub...${NC}"
    ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Conexión SSH a GitHub exitosa${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo autenticar con GitHub${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}📋 PASOS PARA AGREGAR LA CLAVE SSH A GITHUB:${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}IMPORTANTE: Debes copiar la CLAVE PÚBLICA completa (no el fingerprint)${NC}"
        echo ""
        echo -e "${YELLOW}1. COPIA esta clave pública SSH completa:${NC}"
        echo ""
        if [ -n "$ssh_pub_key" ]; then
            echo -e "${GREEN}───────────────────────────────────────────────────────────${NC}"
            echo -e "${GREEN}$ssh_pub_key${NC}"
            echo -e "${GREEN}───────────────────────────────────────────────────────────${NC}"
            echo ""
            echo -e "${YELLOW}   💡 Cópiala completa desde 'ssh-ed25519' hasta el email${NC}"
            echo -e "${YELLOW}   También puedes copiarla con:${NC}"
            echo "   cat ${ssh_key_path}.pub | xclip -selection clipboard  # (si tienes xclip)"
            echo "   cat ${ssh_key_path}.pub"
        else
            echo "   cat ${ssh_key_path}.pub"
        fi
        echo ""
        echo -e "${YELLOW}2. Abre GitHub en tu navegador:${NC}"
        echo "   ${GREEN}https://github.com/settings/ssh/new${NC}"
        echo ""
        echo -e "${YELLOW}3. En GitHub verás dos campos:${NC}"
        echo "   ${GREEN}Title:${NC} Dale un nombre descriptivo"
        echo "          Ejemplo: Frappe Development - $(hostname)"
        echo ""
        echo "   ${GREEN}Key:${NC}   PEGA aquí la clave pública COMPLETA"
        echo "          (la línea completa que empieza con 'ssh-ed25519' o 'ssh-rsa')"
        echo ""
        echo -e "${YELLOW}4. Haz clic en 'Add SSH key'${NC}"
        echo ""
        echo -e "${YELLOW}5. GitHub te pedirá tu contraseña para confirmar${NC}"
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "Presiona ENTER cuando hayas agregado la clave a GitHub..."
        
        # Test again
        echo -e "${GREEN}Probando conexión nuevamente...${NC}"
        ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ ¡Conexión SSH a GitHub exitosa!${NC}"
        else
            echo -e "${YELLOW}⚠️  Aún no se puede conectar. Verifica que la clave esté agregada correctamente.${NC}"
            read -p "¿Deseas continuar de todos modos? (s/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    # Update .env file with SSH key path if not already set
    if [ -n "$ssh_key_path" ] && [ -f .env ]; then
        if ! grep -q "^SSH_PRIVATE_KEY=" .env 2>/dev/null; then
            echo "" >> .env
            echo "# SSH Private Key path for private repositories" >> .env
            echo "SSH_PRIVATE_KEY=$ssh_key_path" >> .env
            echo -e "${GREEN}✓ SSH_PRIVATE_KEY agregada a .env: $ssh_key_path${NC}"
        elif ! grep -q "^SSH_PRIVATE_KEY=$ssh_key_path" .env 2>/dev/null; then
            sed -i "s|^SSH_PRIVATE_KEY=.*|SSH_PRIVATE_KEY=$ssh_key_path|" .env
            echo -e "${GREEN}✓ SSH_PRIVATE_KEY actualizada en .env: $ssh_key_path${NC}"
        fi
    fi
    
    # Export for docker build
    export SSH_PRIVATE_KEY="$ssh_key_path"
    
    # Read the actual key content and encode it in base64 for docker build
    if [ -f "$ssh_key_path" ]; then
        export SSH_PRIVATE_KEY_CONTENT=$(cat "$ssh_key_path" | base64 -w 0)
    fi
    
    return 0
}

# Verify that .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure the required variables${NC}"
    exit 1
fi

# Load variables from .env
echo -e "${GREEN}Loading variables from .env...${NC}"
export $(grep -v '^#' .env | xargs)

# Check and setup SSH keys
check_and_setup_ssh

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

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  CUSTOM_APPS: $CUSTOM_APPS"
echo "  FRAPPE_BRANCH: $FRAPPE_BRANCH"
echo "  PYTHON_VERSION: $PYTHON_VERSION"
echo "  IMAGE: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
echo "  FRAPPE_PORT: $FRAPPE_PORT (auto-detected)"
if [ -n "$SSH_PRIVATE_KEY" ]; then
    echo "  SSH_PRIVATE_KEY: $SSH_PRIVATE_KEY (configured)"
else
    echo "  SSH_PRIVATE_KEY: (not configured)"
fi
echo ""

# Build the image
echo -e "${GREEN}Starting image build...${NC}"

# Use key content if available, otherwise use path
if [ -n "$SSH_PRIVATE_KEY_CONTENT" ]; then
    docker build \
        --build-arg SSH_PRIVATE_KEY="$SSH_PRIVATE_KEY_CONTENT" \
        --build-arg CUSTOM_APPS="$CUSTOM_APPS" \
        --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
        --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
        -t ${CUSTOM_IMAGE}:${CUSTOM_TAG} \
        -f images/develop/Containerfile \
        .
else
    docker build \
        --build-arg SSH_PRIVATE_KEY="$SSH_PRIVATE_KEY" \
        --build-arg CUSTOM_APPS="$CUSTOM_APPS" \
        --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
        --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
        -t ${CUSTOM_IMAGE}:${CUSTOM_TAG} \
        -f images/develop/Containerfile \
        .
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully: ${CUSTOM_IMAGE}:${CUSTOM_TAG}${NC}"
else
    echo -e "${RED}✗ Error building image${NC}"
    exit 1
fi

# Compose and start services
echo -e "${GREEN}Starting services with docker-compose...${NC}"
docker-compose -f compose.yaml up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Services started successfully${NC}"
    echo -e "${YELLOW}Waiting for services to initialize (30 seconds)...${NC}"
    sleep 30
    echo -e "${GREEN}Services status:${NC}"
    docker-compose -f compose.yaml ps
    
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
