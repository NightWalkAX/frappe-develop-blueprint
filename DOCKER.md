# Docker Setup

## Requirements
- Docker
- Docker Compose

## Image Build

```bash
docker build -f images/develop/Containerfile -t travel-agent-erp:latest .
```

## Configuration

Edit the `.env` file and configure:

```env
CUSTOM_IMAGE=travel-agent-erp
CUSTOM_TAG=latest
DB_PASSWORD=your_secure_password
```

## Start Services

```bash
docker compose up -d
```

## Create the Site

```bash
docker compose exec backend bench new-site sitename --admin-password admin --db-root-password your_secure_password
docker compose exec backend bench --site sitename install-app travel_agency_erp
docker compose exec backend bench --site sitename set-config developer_mode 1
```

## Access

- Frontend: http://localhost:8080
- User: Administrator
- Password: admin

## Useful Commands

```bash
# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop services
docker compose down

# Access backend
docker compose exec backend bash
```
