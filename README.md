# Frappe ERP - Development Environment

> 🚀 Plug-and-play Docker development environment for Frappe-based ERP.

This repository provides a complete development environment for a system based on Frappe framework.

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
# Custom Apps Configuration (comma-separated list)
# Format: repo1:branch1,repo2:branch2,repo3:branch3
# If branch is omitted, 'develop' will be used by default
CUSTOM_APPS=YourUsername/your_app:develop,YourUsername/another_app:main

# Site Configuration (auto-setup)
SITE_NAME=erp.local
ADMIN_PASSWORD=admin

# Database
DB_PASSWORD=your_secure_password

# Image Configuration
CUSTOM_IMAGE=frappe-erp
CUSTOM_TAG=latest

# For private repositories
GITHUB_TOKEN=github_pat_xxxxxxxxxxxxx
```

**Examples:**
- Single app: `CUSTOM_APPS=myorg/myapp:main`
- Multiple apps: `CUSTOM_APPS=myorg/app1:develop,myorg/app2:main,myorg/app3:version-14`
- Using default branch: `CUSTOM_APPS=myorg/app1,myorg/app2:main` (app1 will use 'develop')

**Important Notes:**
- 📋 **Order matters**: Apps are installed in the order listed
- 🔗 **Dependencies**: If app B depends on app A, list app A first
- 🌿 **Default branch**: If no branch is specified, `develop` is used
- 🔑 **Private repos**: Set `GITHUB_TOKEN` for private repositories

### 3. Build & Deploy

#### Using the build script (recommended):
```bash
./build.sh
```

The script will automatically:
- 🔍 **Detect an available port** in the range 8000-8099
- 🏗️ Build the Docker image with your custom apps
- 🚀 Start all services with the detected port

**Port auto-detection**: Perfect for running multiple instances on the same VM. Each instance automatically gets a unique port without manual configuration.

To force a specific port, set `FRAPPE_PORT` in your `.env` file:
```bash
FRAPPE_PORT=8005  # Optional: force specific port
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
- ✅ Instalación automática de todas las apps especificadas en `CUSTOM_APPS`
- ✅ Activación del modo desarrollador
- ✅ Configuración lista para usar

### 5. Verify Installation

Check the logs to ensure apps were installed successfully:
```bash
docker compose logs backend | grep "Installing app"
```

You should see messages like:
- `📱 Installing app: <app_name>` - App installation started
- `✅ App <app_name> installed successfully` - App installed

### 6. (Optional) Manual Commands

If you need to create additional sites or perform manual configurations:

```bash
# Access the backend container
docker compose exec backend bash

# Create additional site
bench new-site another.site.local --admin-password admin --db-root-password your_secure_password

# Install app in additional site
bench --site another.site.local install-app your_app_name

# Exit container
exit
```

### 7. Access Your ERP

- **Frontend**: http://localhost:PORT (port shown after build.sh completes)
- **User**: Administrator
- **Password**: admin (or what you set in `ADMIN_PASSWORD`)

> 💡 **Tip**: The port is automatically detected and displayed at the end of the build process. Multiple developers can run their own instance on the same VM without port conflicts.

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

- [Custom Apps Installation Guide](docs/APPS_INSTALLATION.md) - Detailed guide for installing multiple apps
- [Docker Setup Guide](DOCKER.md)
- [Environment Variables Reference](.env.example)

## 🐛 Troubleshooting

### Apps not installed

**Check build logs:**
```bash
docker compose build backend 2>&1 | grep "Installing app"
```

**View installation logs:**
```bash
docker compose logs backend | grep -E "Installing app|installed successfully|not found"
```

**Common issues:**
- ⚠️ `App <app_name> not found in apps/` - Build issue, rebuild with correct `CUSTOM_APPS`
- ⚠️ Invalid repository format - Ensure format is `owner/repo:branch`
- ⚠️ Private repo access denied - Verify `GITHUB_TOKEN` has correct permissions

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

This development environment template is part of the Frappe ERP project.

## 🤝 Contributing

For issues or improvements to this development environment, please contact the development team.
