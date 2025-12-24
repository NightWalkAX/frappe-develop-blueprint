# Travel Agent ERP - Docker Development Setup

## Archivos necesarios en tu repo

```
/
├── Dockerfile (o Containerfile.template)
├── docker-compose.yml
├── .env.example
├── .gitignore
├── resources/
│   ├── nginx-template.conf
│   └── nginx-entrypoint.sh
└── README.md
```

## Setup

1. **Copia el archivo de environment:**
   ```bash
   cp .env.example .env
   ```

2. **Edita `.env` con tus credenciales:**
   ```bash
   # Configura tu repo
   CUSTOM_APP_REPO=TuUsername/tu_app
   CUSTOM_APP_BRANCH=develop
   
   # Si tu repo es privado, agrega tu GitHub token
   GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
   ```

3. **Build de la imagen:**
   ```bash
   docker build \
     --build-arg GITHUB_TOKEN=$(grep GITHUB_TOKEN .env | cut -d '=' -f2) \
     --build-arg CUSTOM_APP_REPO=$(grep CUSTOM_APP_REPO .env | cut -d '=' -f2) \
     --build-arg CUSTOM_APP_BRANCH=$(grep CUSTOM_APP_BRANCH .env | cut -d '=' -f2) \
     -t travel-agent-erp:latest \
     -f Dockerfile .
   ```

4. **O usa docker-compose:**
   ```bash
   docker-compose up -d
   ```

## Notas de Seguridad

- ⚠️ **NUNCA** commitees `.env` con credenciales reales
- ⚠️ **NUNCA** hardcodees tokens en el Dockerfile
- ✅ Usa build args para pasar credenciales en tiempo de build
- ✅ Usa `.gitignore` para excluir archivos sensibles
