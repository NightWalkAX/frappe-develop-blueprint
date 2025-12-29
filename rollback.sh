#!/bin/bash
set -e

# Rollback script for deployments
# Usage: ./rollback.sh <version-tag>

if [ -z "$1" ]; then
    echo "❌ Error: You must specify a version tag"
    echo "Usage: $0 <version-tag>"
    echo ""
    echo "Available versions:"
    docker images | grep travel-agency-erp | awk '{print $2}'
    exit 1
fi

VERSION_TAG=$1
SITE_NAME=${FRAPPE_SITE_NAME:-"dev.example.com"}

echo "🔄 Starting rollback to version: $VERSION_TAG"

# Backup before rollback
echo "📦 Creating safety backup..."
docker compose exec -T backend bench --site $SITE_NAME backup --with-files

# Update the tag in .env
echo "📝 Updating .env..."
sed -i "s/CUSTOM_TAG=.*/CUSTOM_TAG=$VERSION_TAG/" .env

# Pull specific image
echo "📥 Pulling image $VERSION_TAG..."
docker compose pull

# Restart services
echo "♻️ Restarting services..."
docker compose down
docker compose up -d

# Verify
echo "⏳ Waiting for services to be ready..."
sleep 15

echo "🧪 Checking services status..."
docker compose ps

echo "✅ Rollback completed!"
echo "💡 If there are issues, backups are located at:"
docker compose exec -T backend bench --site $SITE_NAME list-backups | tail -5
