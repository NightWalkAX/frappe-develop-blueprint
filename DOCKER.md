# Docker Setup

## Requirements
- Docker
- Docker Compose

## Quick Start

### 1. Configuración inicial

Copia el archivo de ejemplo y configura las variables:

```bash
cp .env.example .env
```

Edita `.env` y configura al menos:

```env
# Aplicaciones personalizadas (opcional)
CUSTOM_APPS=tu-organizacion/tu-app:develop

# Configuración de la base de datos
DB_HOST=mariadb
DB_PORT=3306
DB_PASSWORD=cambia_esto_en_produccion
DB_NAME=frappe_db
DB_USER=frappe

# Configuración de Redis
REDIS_CACHE=redis-cache:6379
REDIS_QUEUE=redis-queue:6379

# Configuración del sitio
SITE_NAME=dpe.erp.local
ADMIN_PASSWORD=admin
```

### 2. Construir la imagen

**En Linux/macOS:**
```bash
./build.sh
```

**En Windows:**
```cmd
build.bat
```

O manualmente:
```bash
docker build -f images/develop/Containerfile -t frappe-custom:latest .
```

### 3. Actualizar el compose.yaml

Configura la imagen personalizada en `.env`:

```env
CUSTOM_IMAGE=frappe-custom
CUSTOM_TAG=latest
```

### 4. Iniciar los servicios

```bash
docker compose up -d
```

Esto iniciará:
- **mariadb**: Base de datos MariaDB 10.6
- **redis-cache**: Redis para caché
- **redis-queue**: Redis para colas
- **configurator**: Configura el entorno inicial
- **backend**: Servidor backend de Frappe
- **frontend**: Servidor web Nginx
- **websocket**: Servidor WebSocket
- **queue-short**: Worker para tareas cortas
- **queue-long**: Worker para tareas largas
- **scheduler**: Programador de tareas

### 5. Verificar que los servicios estén corriendo

```bash
docker compose ps
```

Todos los servicios deben estar en estado "healthy" o "running".

## Crear el Sitio

```bash
docker compose exec backend bench new-site ${SITE_NAME} \
  --admin-password ${ADMIN_PASSWORD} \
  --db-root-password ${DB_PASSWORD}
```

Si tienes aplicaciones personalizadas, instálalas:

```bash
docker compose exec backend bench --site ${SITE_NAME} install-app nombre_app
```

Habilitar modo desarrollador (opcional):

```bash
docker compose exec backend bench --site ${SITE_NAME} set-config developer_mode 1
docker compose restart backend
```

## Acceso

- Frontend: http://localhost:8080
- Usuario: Administrator
- Contraseña: la que configuraste en `ADMIN_PASSWORD`

## Comandos Útiles

### Ver logs

```bash
# Todos los servicios
docker compose logs -f

# Servicio específico
docker compose logs -f backend
docker compose logs -f mariadb
docker compose logs -f redis-cache
```

### Reiniciar servicios

```bash
# Todos
docker compose restart

# Específico
docker compose restart backend
```

### Detener servicios

```bash
# Detener sin eliminar volúmenes
docker compose down

# Detener y eliminar volúmenes (¡cuidado! se perderán los datos)
docker compose down -v
```

### Acceder al backend

```bash
docker compose exec backend bash
```

### Ejecutar comandos de bench

```bash
# Migrar
docker compose exec backend bench --site ${SITE_NAME} migrate

# Console
docker compose exec backend bench --site ${SITE_NAME} console

# Clear cache
docker compose exec backend bench --site ${SITE_NAME} clear-cache
```

### Backup y Restore

```bash
# Backup
docker compose exec backend bench --site ${SITE_NAME} backup

# Restore
docker compose exec backend bench --site ${SITE_NAME} restore /path/to/backup
```

## Solución de Problemas

### El sitio no carga

1. Verifica que todos los servicios estén corriendo:
   ```bash
   docker compose ps
   ```

2. Verifica los logs:
   ```bash
   docker compose logs -f backend
   ```

3. Verifica la conectividad con MariaDB:
   ```bash
   docker compose exec backend bench --site ${SITE_NAME} mariadb
   ```

4. Verifica la conectividad con Redis:
   ```bash
   docker compose exec redis-cache redis-cli ping
   docker compose exec redis-queue redis-cli ping
   ```

### Error de conexión a la base de datos

Verifica que MariaDB esté corriendo y las credenciales en `.env` sean correctas:

```bash
docker compose logs mariadb
docker compose exec mariadb mysql -u root -p${DB_PASSWORD}
```

### Error de conexión a Redis

Verifica que Redis esté corriendo:

```bash
docker compose exec redis-cache redis-cli ping
docker compose exec redis-queue redis-cli ping
```

## Estructura de Volúmenes

El `compose.yaml` crea los siguientes volúmenes persistentes:

- `sites`: Archivos del sitio Frappe
- `mariadb-data`: Datos de la base de datos
- `redis-cache-data`: Datos de Redis caché
- `redis-queue-data`: Datos de Redis colas

Para ver los volúmenes:

```bash
docker volume ls | grep mytime
```
