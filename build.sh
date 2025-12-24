#!/bin/bash

# Script to build custom image on Linux/macOS
# Reads variables from .env file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Build Script for Custom Image ===${NC}"

# Verify that .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure the required variables${NC}"
    exit 1
fi

# Load variables from .env
echo -e "${GREEN}Loading variables from .env...${NC}"
export $(grep -v '^#' .env | xargs)

# Verify required variables
if [ -z "$CUSTOM_APPS" ]; then
    echo -e "${YELLOW}Warning: CUSTOM_APPS variable is not defined in .env${NC}"
    echo -e "${YELLOW}No custom apps will be installed. Only Frappe will be available.${NC}"
fi

# Default values
FRAPPE_BRANCH=${FRAPPE_BRANCH:-version-14}
PYTHON_VERSION=${PYTHON_VERSION:-3.11.6}

echo -e "${GREEN}Configuration:${NC}"
echo "  CUSTOM_APPS: $CUSTOM_APPS"
echo "  FRAPPE_BRANCH: $FRAPPE_BRANCH"
echo "  PYTHON_VERSION: $PYTHON_VERSION"
if [ -n "$GITHUB_TOKEN" ]; then
    echo "  GITHUB_TOKEN: ******* (configured)"
else
    echo "  GITHUB_TOKEN: (not configured - may fail on private repositories)"
fi

# Build the image
echo -e "${GREEN}Starting image build...${NC}"

docker build \
    --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" \
    --build-arg CUSTOM_APPS="$CUSTOM_APPS" \
    --build-arg FRAPPE_BRANCH="$FRAPPE_BRANCH" \
    --build-arg PYTHON_VERSION="$PYTHON_VERSION" \
    -t frappe-custom:latest \
    -f images/develop/Containerfile \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Image built successfully: frappe-custom:latest${NC}"
else
    echo -e "${RED}✗ Error building image${NC}"
    exit 1
fi
