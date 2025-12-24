# Docker Setup

## Requisitos
- Docker
- Docker Compose

## Construcción de la Imagen

```bash
docker build -f images/develop/Containerfile -t travel-agent-erp:latest .
```

## Configuración

Edita el archivo `.env` y configura:

```env
CUSTOM_IMAGE=travel-agent-erp
CUSTOM_TAG=latest
DB_PASSWORD=tu_password_seguro
```

## Levantar Servicios

```bash
docker compose up -d
```

## Crear el Sitio

```bash
docker compose exec backend bench new-site sitename --admin-password admin --db-root-password tu_password_seguro
docker compose exec backend bench --site sitename install-app travel_agency_erp
docker compose exec backend bench --site sitename set-config developer_mode 1
```

## Acceso

- Frontend: http://localhost:8080
- Usuario: Administrator
- Contraseña: admin

## Comandos Útiles

```bash
# Ver logs
docker compose logs -f

# Reiniciar servicios
docker compose restart

# Detener servicios
docker compose down

# Acceder al backend
docker compose exec backend bash
```
