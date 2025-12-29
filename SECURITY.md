## 🔵 **SECURITY CONSIDERATIONS - DEVELOP BRANCH**

> **📅 Last review:** December 29, 2025  
> **🔧 Environment:** Local development  
> **⚠️ IMPORTANT:** This is a **DEVELOPMENT** environment. The configurations described here are appropriate for local development and **should NOT be used in production**.

---

## ℹ️ **ABOUT THIS BRANCH**

This branch (`develop`) is designed for **local development environments**. Default configurations facilitate quick setup and debugging, prioritizing ease of use over strict security.

**For production deployments**, please refer to the `production` branch where additional security measures are implemented.

---

## 📋 **DEVELOPMENT CONFIGURATIONS**

The following configurations are **intentional** to facilitate development:

### 1. **Default credentials in `.env.example`**

```dotenv
ADMIN_PASSWORD=admin
DB_PASSWORD=frappe_password
```

✅ **Acceptable in development:** Allows quick setup without additional configuration.

---

### 2. **GITHUB_TOKEN in build args**

```dockerfile
docker build --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" ...
```

✅ **Acceptable in development:** Simplifies the build process for private repositories.

---

### 3. **Database with simple configuration**

```yaml
mariadb:
  environment:
    MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-frappe_password}
```

✅ **Acceptable in development:** Facilitates local access for debugging.

---

### 4. **Git credentials in container**

✅ **Acceptable in development:** Allows easy cloning of private repositories during build.

---

### 5. **Direct installation scripts**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
```

✅ **Acceptable in development:** Standard NVM installation for development environments.

---

### 6. **Automatic addition to docker group**

```bash
sudo usermod -aG docker $USER
```

✅ **Acceptable in development:** Convenience for local developers.

---

### 7. **Flexible dependency versions**

```yaml
image: mariadb:10.6
image: redis:7-alpine
```

✅ **Acceptable in development:** Allows receiving minor updates automatically.

---

## 📋 **SUMMARY TABLE**

| # | Configuration | Status in Develop | Notes |
|---|---------------|-------------------|-------|
| 1 | Default credentials | ✅ OK | Facilitates quick setup |
| 2 | GitHub token in build-arg | ✅ OK | Simplifies builds |
| 3 | DB without extra restrictions | ✅ OK | Easy access for debug |
| 4 | Git credentials in container | ✅ OK | For private repos |
| 5 | Direct external scripts | ✅ OK | Standard installation |
| 6 | Auto-add to docker group | ✅ OK | Local convenience |
| 7 | Flexible versions | ✅ OK | Automatic updates |
| 8 | Localhost port | ✅ OK | Local access only |
| 9 | No strict validation | ✅ OK | Agile development |
| 10 | Standard permissions | ✅ OK | Development environment |

---

## 🚀 **FOR PRODUCTION**

If you need to deploy to production, consider:

1. **Use the `production` branch** which includes:
   - BuildKit secrets for tokens
   - Strong password validation
   - Pinned dependency versions
   - Credential cleanup in images

2. **Production checklist:**
   - [ ] Change all default passwords
   - [ ] Configure SSL/TLS
   - [ ] Implement automatic backups
   - [ ] Configure monitoring and alerts
   - [ ] Review network policies

---

## �� **CONTACT**

To report security issues in production:
- Send an email to: [jymendev@gmail.com]
- Do not publish vulnerabilities in public Issues

---
