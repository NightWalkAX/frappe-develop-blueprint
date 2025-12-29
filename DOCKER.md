# Docker Setup

## Requirements
- Docker
- Docker Compose

## Quick Start

### 1. Initial Setup

Copy the example file and configure the variables:

```bash
cp .env.example .env
```

Edit `.env` and configure at least:

```env
# Custom applications (optional)
CUSTOM_APPS=your-organization/your-app:develop

# Database configuration
DB_HOST=mariadb
DB_PORT=3306
DB_PASSWORD=change_this_in_production
DB_NAME=frappe_db
DB_USER=frappe

# Redis configuration
REDIS_CACHE=redis-cache:6379
REDIS_QUEUE=redis-queue:6379

# Site configuration
SITE_NAME=erp.local
ADMIN_PASSWORD=admin
```

### 2. Build the Image

**On Linux/macOS:**
```bash
./build.sh
```

**On Windows:**
```cmd
build.bat
```

Or manually:
```bash
docker build -f images/develop/Containerfile -t frappe-custom:latest .
```

### 3. Update compose.yaml

Configure the custom image in `.env`:

```env
CUSTOM_IMAGE=frappe-custom
CUSTOM_TAG=latest
```

### 4. Start the Services

```bash
docker compose up -d
```

This will start:
- **mariadb**: MariaDB 10.6 database
- **redis-cache**: Redis for caching
- **redis-queue**: Redis for queues
- **configurator**: Configures the initial environment
- **backend**: Frappe backend server
- **frontend**: Nginx web server
- **websocket**: WebSocket server
- **queue-short**: Worker for short tasks
- **queue-long**: Worker for long tasks
- **scheduler**: Task scheduler

### 5. Verify Services Are Running

```bash
docker compose ps
```

All services should be in "healthy" or "running" state.

## Create the Site

```bash
docker compose exec backend bench new-site ${SITE_NAME} \
  --admin-password ${ADMIN_PASSWORD} \
  --db-root-password ${DB_PASSWORD}
```

If you have custom applications, install them:

```bash
docker compose exec backend bench --site ${SITE_NAME} install-app app_name
```

Enable developer mode (optional):

```bash
docker compose exec backend bench --site ${SITE_NAME} set-config developer_mode 1
docker compose restart backend
```

## Access

- Frontend: http://localhost:8080
- Username: Administrator
- Password: the one you configured in `ADMIN_PASSWORD`

## Useful Commands

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f mariadb
docker compose logs -f redis-cache
```

### Restart Services

```bash
# All
docker compose restart

# Specific
docker compose restart backend
```

### Stop Services

```bash
# Stop without removing volumes
docker compose down

# Stop and remove volumes (caution! data will be lost)
docker compose down -v
```

### Access the Backend

```bash
docker compose exec backend bash
```

### Run Bench Commands

```bash
# Migrate
docker compose exec backend bench --site ${SITE_NAME} migrate

# Console
docker compose exec backend bench --site ${SITE_NAME} console

# Clear cache
docker compose exec backend bench --site ${SITE_NAME} clear-cache
```

### Backup and Restore

```bash
# Backup
docker compose exec backend bench --site ${SITE_NAME} backup

# Restore
docker compose exec backend bench --site ${SITE_NAME} restore /path/to/backup
```

## Troubleshooting

### Site Not Loading

1. Verify all services are running:
   ```bash
   docker compose ps
   ```

2. Check the logs:
   ```bash
   docker compose logs -f backend
   ```

3. Verify MariaDB connectivity:
   ```bash
   docker compose exec backend bench --site ${SITE_NAME} mariadb
   ```

4. Verify Redis connectivity:
   ```bash
   docker compose exec redis-cache redis-cli ping
   docker compose exec redis-queue redis-cli ping
   ```

### Database Connection Error

Verify MariaDB is running and the credentials in `.env` are correct:

```bash
docker compose logs mariadb
docker compose exec mariadb mysql -u root -p${DB_PASSWORD}
```

### Redis Connection Error

Verify Redis is running:

```bash
docker compose exec redis-cache redis-cli ping
docker compose exec redis-queue redis-cli ping
```

## Volume Structure

The `compose.yaml` creates the following persistent volumes:

- `sites`: Frappe site files
- `mariadb-data`: Database data
- `redis-cache-data`: Redis cache data
- `redis-queue-data`: Redis queue data

To view the volumes:

```bash
docker volume ls | grep mytime
```
