# Custom Apps Installation Guide

This Docker image now supports installing multiple custom Frappe apps from GitHub repositories using a simple environment variable configuration.

## Configuration

### Environment Variable: `CUSTOM_APPS`

The `CUSTOM_APPS` environment variable accepts a comma-separated list of GitHub repositories and their branches.

**Format:**
```
CUSTOM_APPS=repo1:branch1,repo2:branch2,repo3:branch3
```

**Examples:**

1. **Single app with branch:**
   ```bash
   CUSTOM_APPS=myorg/travel_agency_erp:main
   ```

2. **Multiple apps with different branches:**
   ```bash
   CUSTOM_APPS=myorg/app1:develop,myorg/app2:main,myorg/app3:version-14
   ```

3. **Apps with default branch (develop):**
   ```bash
   CUSTOM_APPS=myorg/app1,myorg/app2:main,myorg/app3
   ```
   In this case, `app1` and `app3` will use the `develop` branch by default.

## How It Works

### Build Time (Containerfile)

During the Docker image build:

1. The `CUSTOM_APPS` variable is read
2. Each app repository is cloned using `bench get-app`
3. Apps are downloaded with retry logic (up to 5 attempts)
4. The app list is saved to `/home/frappe/frappe-bench/.custom_apps_list`

### Runtime (Entrypoint)

When the container starts:

1. The database and Redis connections are verified
2. A new Frappe site is created (if it doesn't exist)
3. Each app from the saved list is installed using `bench install-app`
4. Developer mode is enabled
5. The site is ready to use

## Usage Example

### In `.env` file:

```bash
# Custom apps to install
CUSTOM_APPS=mycompany/custom_erp:main,mycompany/reports_app:develop,mycompany/integrations:version-14

# SSH Private Key for accessing private GitHub repositories (base64 encoded)
# Generate with: cat ~/.ssh/id_rsa | base64 -w 0
# Leave empty if only using public repositories
SSH_PRIVATE_KEY=

# Frappe configuration
FRAPPE_BRANCH=version-14
PYTHON_VERSION=3.11.6

# Site configuration
SITE_NAME=mysite.local
ADMIN_PASSWORD=admin
```

### Build the image:

```bash
docker compose build backend
```

### Run the container:

```bash
docker compose up
```

## Important Notes

1. **Order matters**: Apps are installed in the order they appear in `CUSTOM_APPS`
2. **Dependencies**: If app B depends on app A, list app A first
3. **Branch defaults**: If no branch is specified, `develop` is used
4. **SSH Authentication**: Use `SSH_PRIVATE_KEY` (base64 encoded) for private repositories
5. **App names**: The app name is derived from the repository name (e.g., `myorg/my-app` → `my-app`)

## SSH Key Setup for Private Repositories

To access private GitHub repositories, you need to configure an SSH key:

### 1. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### 2. Add SSH Key to GitHub

Copy your public key:
```bash
cat ~/.ssh/id_rsa.pub
```

Add it to GitHub: Settings → SSH and GPG keys → New SSH key

### 3. Encode Private Key for Docker Build

```bash
cat ~/.ssh/id_rsa | base64 -w 0
```

Copy the output and add it to your `.env` file:
```bash
SSH_PRIVATE_KEY=LS0tLS1CRUdJTi...rest_of_base64_string
```

**Security Note**: Never commit the `.env` file with your private key to version control. The `.env` file should be in `.gitignore`.

## Troubleshooting

### App not found during installation

Check the build logs to ensure the app was successfully cloned:
```bash
docker compose build backend 2>&1 | grep "Installing app"
```

### Installation errors

View the container logs:
```bash
docker compose logs backend
```

Look for messages like:
- `📱 Installing app: <app_name>` - App installation started
- `✅ App <app_name> installed successfully` - App installed
- `⚠️ App <app_name> not found in apps/` - App missing (build issue)

### Private repositories

Ensure your SSH key is properly configured and has access to the private repositories. You can test SSH access with:

```bash
ssh -T git@github.com
```

You should see a message like: "Hi username! You've successfully authenticated..."

## Migration from Old Configuration

If you were using the old single-app configuration:

**Old (deprecated):**
```bash
CUSTOM_APP_REPO=myorg/myapp
CUSTOM_APP_BRANCH=develop
CUSTOM_APP_NAME=myapp
```

**New:**
```bash
CUSTOM_APPS=myorg/myapp:develop
```

The `CUSTOM_APP_NAME` and `CUSTOM_APP_REPO` variables are no longer needed.
