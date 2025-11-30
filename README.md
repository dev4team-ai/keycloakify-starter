# Keycloakify Starter Theme

Custom Keycloak login theme built with [Keycloakify](https://www.keycloakify.dev/).

## Theme Structure

```
keycloakify-starter/
├── Dockerfile           # Docker image for theme deployment
├── README.md            # This file
└── login/               # Login theme files
    ├── theme.properties # Theme configuration
    ├── *.ftl            # FreeMarker templates
    ├── messages/        # i18n translations
    └── resources/       # Static assets (CSS, JS, images)
        ├── css/
        ├── dist/        # Keycloakify compiled assets
        ├── img/
        ├── js/
        └── resources-common/
```

## Deploying Theme Changes

### Prerequisites

- Docker with buildx support
- Access to Docker Hub (`protonmath` account)
- kubectl configured for the target cluster

### Step-by-Step Deployment

#### 1. Make your theme changes

Edit files in the `login/` directory:
- **Templates**: `*.ftl` files (FreeMarker)
- **Styles**: `resources/css/login.css`
- **Translations**: `messages/messages_*.properties`
- **Images**: `resources/img/`

#### 2. Build and push the Docker image

```bash
# Navigate to the theme directory
cd charts/keycloak/themes/keycloakify-starter

# Build and push (use linux/amd64 for K8s cluster compatibility)
docker buildx build --platform linux/amd64 \
  -t protonmath/keycloakify-starter:latest \
  --push .
```

#### 3. Restart Keycloak to pick up new theme

```bash
# Restart the Keycloak deployment to pull the new image
kubectl rollout restart deployment keycloak -n gptbot

# Watch the rollout progress
kubectl rollout status deployment keycloak -n gptbot

# Verify the new pod is running
kubectl get pods -n gptbot -l app.kubernetes.io/name=keycloak
```

#### 4. Verify the theme is applied

```bash
# Check init container logs to confirm theme was copied
kubectl logs -n gptbot -l app.kubernetes.io/name=keycloak -c copy-theme

# Check theme files in the running pod
kubectl exec -n gptbot deployment/keycloak -- ls -la /opt/keycloak/themes/keycloakify-starter/login/
```

### Quick One-Liner

```bash
# Build, push, and deploy in one command
cd charts/keycloak/themes/keycloakify-starter && \
docker buildx build --platform linux/amd64 -t protonmath/keycloakify-starter:latest --push . && \
kubectl rollout restart deployment keycloak -n gptbot && \
kubectl rollout status deployment keycloak -n gptbot
```

### PowerShell Version

```powershell
# Build, push, and deploy
cd charts\keycloak\themes\keycloakify-starter
docker buildx build --platform linux/amd64 -t protonmath/keycloakify-starter:latest --push .
kubectl rollout restart deployment keycloak -n gptbot
kubectl rollout status deployment keycloak -n gptbot
```

## How It Works

1. **Theme files are stored in git** (`gptbot-helm` repo) for version control
2. **Docker image is built** from the `Dockerfile` containing just the theme files
3. **Helm chart excludes theme files** via `.helmignore` (avoids >1MB release secret limit)
4. **Init container copies theme** from Docker image to Keycloak's themes directory
5. **Keycloak loads the theme** on startup from `/opt/keycloak/themes/keycloakify-starter`

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Git Repository (gptbot-helm)                                │
│  └── charts/keycloak/themes/keycloakify-starter/           │
│       ├── Dockerfile                                        │
│       └── login/  ← Theme source files                     │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼ docker build & push
┌─────────────────────────────────────────────────────────────┐
│ Docker Hub                                                  │
│  └── protonmath/keycloakify-starter:latest                 │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼ kubectl rollout restart
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes (gptbot namespace)                               │
│  └── Keycloak Pod                                          │
│       ├── Init Container: copy-theme                        │
│       │    └── Copies /theme/* → /theme-data/              │
│       └── Main Container: keycloak                          │
│            └── Mounts /opt/keycloak/themes (emptyDir)      │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

The theme is configured in the Keycloak Helm values:

```yaml
# clusters/developing/apps/keycloak/values.yaml
theme:
  enabled: true
  name: "keycloakify-starter"
  image:
    repository: protonmath/keycloakify-starter
    tag: "latest"
    pullPolicy: Always  # Always pull to get latest changes
  sourcePath: "/theme"
```

## Troubleshooting

### Theme not updating after restart

1. Verify the image was pushed:
   ```bash
   docker pull protonmath/keycloakify-starter:latest
   docker inspect protonmath/keycloakify-starter:latest | grep Created
   ```

2. Check init container logs:
   ```bash
   kubectl logs -n gptbot -l app.kubernetes.io/name=keycloak -c copy-theme
   ```

3. Force image pull by deleting the pod:
   ```bash
   kubectl delete pod -n gptbot -l app.kubernetes.io/name=keycloak
   ```

### Theme files missing

1. Check if files exist in the theme image:
   ```bash
   docker run --rm protonmath/keycloakify-starter:latest ls -la /theme/login/
   ```

2. Verify the Dockerfile copies the correct path

### Keycloak shows default theme

1. Check realm configuration has the correct theme:
   ```bash
   kubectl exec -n gptbot deployment/keycloak -- \
     cat /opt/keycloak/data/import/realm.json | grep loginTheme
   ```

2. Verify theme.properties exists:
   ```bash
   kubectl exec -n gptbot deployment/keycloak -- \
     cat /opt/keycloak/themes/keycloakify-starter/login/theme.properties
   ```

## Development Tips

- **Test locally**: Run Keycloak locally with the theme mounted as a volume
- **Browser cache**: Clear browser cache or use incognito mode when testing
- **Hot reload**: For development, consider using Keycloakify's dev server
- **Translations**: Add new locales in `messages/messages_<locale>.properties`
