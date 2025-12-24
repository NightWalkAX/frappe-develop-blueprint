# DP Electric (MyTime) ERP - Development Environment

> 🚀 Plug-and-play Docker development environment for MyTime ERP

This repository provides a complete, production-ready development environment for the MyTime ERP system based on Frappe framework.

## 📁 Repository Structure

```
/
├── compose.yaml                   # Docker Compose configuration
├── build.sh                       # Build script for Docker images
├── build.bat                      # Build script for Windows
├── health-check.sh                # Health monitoring script
├── rollback.sh                    # Deployment rollback script
├── .env.example                   # Environment variables template
├── DOCKER.md                      # Docker setup documentation
├── README.md                      # This file
├── docs/                          # Additional documentation
├── images/
│   └── develop/
│       ├── Containerfile          # Docker image definition
│       └── Containerfile.template # Docker image template
└── resources/
    ├── nginx-template.conf        # Nginx configuration template
    └── nginx-entrypoint.sh        # Nginx startup script
```

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose V2
- Git

### 1. Clone and Setup

```bash
cd environment
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` file with your settings:

```bash
# Custom App Configuration
CUSTOM_APP_REPO=YourUsername/your_app
CUSTOM_APP_BRANCH=develop
CUSTOM_APP_NAME=your_app_name

# Site Configuration (auto-setup)
SITE_NAME=dpe.erp.local
ADMIN_PASSWORD=admin

# Database
DB_PASSWORD=your_secure_password

# Image Configuration
CUSTOM_IMAGE=mytime-erp
CUSTOM_TAG=latest

# For private repositories
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
```

### 3. Build & Deploy

#### Using the build script (recommended):
```bash
./build.sh
```

#### Manual build:
```bash
docker build \
  --build-arg GITHUB_TOKEN=${GITHUB_TOKEN} \
  --build-arg CUSTOM_APP_REPO=${CUSTOM_APP_REPO} \
  --build-arg CUSTOM_APP_BRANCH=${CUSTOM_APP_BRANCH} \
  -t ${CUSTOM_IMAGE}:${CUSTOM_TAG} \
  -f images/develop/Containerfile .
```

### 4. Start Services

```bash
docker compose up -d
```

Los servicios se iniciarán automáticamente y el sitio será creado con la configuración especificada en el archivo `.env`. El proceso incluye:
- ✅ Creación automática del sitio
### 6. (Opcional) Comandos Manuales

Si necesitas crear sitios adicionales o realizar configuraciones manuales:

```bash
# Access the backend container
docker compose exec backend bash

# Create additional site
bench new-site another.site.local --admin-password admin --db-root-password your_secure_password

# Install app in additional site
bench --site another.site.local install-app your_app_name

# Exit container
exit
```t-password your_secure_password

# Install your custom app
bench --site dpe.erp.local install-app your_app_name

# Enable developer mode
bench --site dpe.erp.local set-config developer_mode 1

# Set site in current site
python -m restart.py

# Exit container
exit
```

### 6. Access Your ERP

- **Frontend**: http://localhost:8080
- **User**: Administrator
- **Password**: admin (or what you set during site creation)

## 🛠️ Management Scripts

### Health Check
Monitor your deployment status:
```bash
./health-check.sh
```

This checks:
- Container status
- HTTP connectivity
- API responses
- Database connection
- Queue workers
- Resource usage
- Recent errors

### Rollback
Rollback to a previous version:
```bash
./rollback.sh <version-tag>
```

## 📋 Common Commands

```bash
# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend

# Restart services
docker compose restart

# Stop all services
docker compose down

# Stop and remove volumes (⚠️ deletes data)
docker compose down -v

# Access backend shell
docker compose exec backend bash

# Run bench commands
docker compose exec backend bench --site dev.example.com migrate
docker compose exec backend bench --site dev.example.com clear-cache

# Create backup
docker compose exec backend bench --site dev.example.com backup --with-files

# List backups
docker compose exec backend bench --site dev.example.com list-backups
```

## 🔧 Development Workflow

1. **Make changes** to your custom app code
2. **Restart** the backend service:
   ```bash
   docker compose restart backend
   ```
3. **Clear cache** if needed:
   ```bash
   docker compose exec backend bench --site dev.example.com clear-cache
   ```
4. **Run migrations** after schema changes:
   ```bash
   docker compose exec backend bench --site dev.example.com migrate
   ```

## 🏗️ Architecture

The environment includes:

- **Backend**: Frappe/ERPNext application server
- **Database**: MariaDB 10.6
- **Cache**: Redis (cache + queue)
- **Proxy**: Nginx reverse proxy
- **Workers**: Background job processors
- **Scheduler**: Cron job manager

## 🔒 Security Notes

- ⚠️ **NEVER** commit `.env` with real credentials
- ⚠️ **NEVER** hardcode tokens in Dockerfiles
- ⚠️ Change default passwords in production
- ✅ Use build args for passing credentials at build time
- ✅ Use `.gitignore` to exclude sensitive files
- ✅ Rotate GitHub tokens periodically
- ✅ Use strong database passwords

## 📚 Additional Documentation

- [Docker Setup Guide](environment/DOCKER.md)
- [Image Documentation](environment/images/develop/README.md)

## 🐛 Troubleshooting

### Services won't start
```bash
# Check logs for errors
docker compose logs

# Verify .env configuration
cat .env

# Check port availability
sudo netstat -tlnp | grep -E '8080|3306|6379'
```

### Site not accessible
```bash
# Run health check
./health-check.sh

# Verify nginx configuration
docker compose exec frontend nginx -t

# Check backend status
docker compose exec backend bench doctor
```

### Database connection issues
```bash
# Check database logs
docker compose logs database

# Verify database is running
docker compose ps database

# Test connection
docker compose exec database mysql -uroot -p${DB_PASSWORD}
```

## 📝 License

This development environment template is part of the MyTime ERP project.

## 🤝 Contributing

For issues or improvements to this development environment, please contact the development team.
