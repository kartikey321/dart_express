# Docker Deployment

Deploy Fletch applications using Docker for consistent, reproducible environments.

## Quick Start

### Dockerfile

Create `Dockerfile`:

```dockerfile
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./

# Install dependencies
RUN dart pub get

# Copy source code
COPY . .

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage
FROM scratch

# Copy the executable
COPY --from=build /app/bin/server /app/bin/server

# Expose port
EXPOSE 3000

# Run the server
ENTRYPOINT ["/app/bin/server"]
```

### Build and Run

```bash
# Build image
docker build -t my-api .

# Run container
docker run -p 3000:3000 my-api
```

## Multi-Stage Build

Optimize image size with multi-stage builds:

```dockerfile
# Build stage
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage (minimal)
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy executable from build stage
COPY --from=build /app/bin/server ./server

EXPOSE 3000

CMD ["./server"]
```

## Environment Variables

### Dockerfile

```dockerfile
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .

# Build with environment support
RUN dart compile exe bin/server.dart -o bin/server

FROM debian:bookworm-slim

WORKDIR /app
COPY --from=build /app/bin/server ./server

# Default environment variables
ENV PORT=3000
ENV SESSION_SECRET=change-me-in-production

EXPOSE ${PORT}

CMD ["./server"]
```

### Application Code

```dart
import 'dart:io';

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final sessionSecret = Platform.environment['SESSION_SECRET']!;
  
  final app = Fletch(
    sessionSecret: sessionSecret,
    secureCookies: true,
  );
  
  app.get('/', (req, res) {
    res.json({'status': 'running'});
  });
  
  await app.listen(port, host: '0.0.0.0');
  print('Server running on port $port');
}
```

### Run with Environment

```bash
docker run -p 3000:3000 \
  -e PORT=3000 \
  -e SESSION_SECRET=your-secret-key \
  my-api
```

## Docker Compose

### Development Setup

`docker-compose.yml`:

```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - SESSION_SECRET=dev-secret-key
      - DB_HOST=mongodb
    depends_on:
      - mongodb
    volumes:
      - .:/app
    command: dart run bin/server.dart

  mongodb:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db

volumes:
  mongo-data:
```

Run:
```bash
docker-compose up
```

### Production Setup

`docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  api:
    image: my-api:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - SESSION_SECRET=${SESSION_SECRET}
      - DB_HOST=mongodb
    depends_on:
      - mongodb

  mongodb:
    image: mongo:latest
    restart: always
    volumes:
      - mongo-data:/data/db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${MONGO_USER}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - api

volumes:
  mongo-data:
```

## Health Checks

Add health check to Dockerfile:

```dockerfile
FROM debian:bookworm-slim

WORKDIR /app
COPY --from=build /app/bin/server ./server

# Add curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["./server"]
```

Application:
```dart
app.get('/health', (req, res) {
  res.json({'status': 'healthy'});
});
```

## Optimization Tips

### Use .dockerignore

`.dockerignore`:
```
.dart_tool/
.packages
build/
*.log
.git/
.gitignore
README.md
docker-compose*.yml
Dockerfile
.env
```

### Cache Dependencies

```dockerfile
# Copy only pubspec first (better caching)
COPY pubspec.* ./
RUN dart pub get

# Then copy source (changes more often)
COPY . .
```

### Reduce Image Size

```dockerfile
# Use scratch for minimal image
FROM scratch

# Or alpine for tiny Dart runner
FROM alpine:latest
RUN apk add --no-cache libc6-compat
```

## Kubernetes Deployment

`deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dart-express-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: my-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: PORT
          value: "3000"
        - name: SESSION_SECRET
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: session-secret
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

## Security Best Practices

1. **Never hardcode secrets** - Use environment variables
2. **Run as non-root user**
3. **Scan images** for vulnerabilities
4. **Use multi-stage builds** to reduce attack surface
5. **Keep base images updated**

<div style="display:flex;justify-content:space-between;gap:1rem;align-items:center;margin:2rem 0;">
  <a href="/core-concepts/error-handling" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span aria-hidden="true">‹</span>
    <span>🚧 Error Handling</span>
  </a>
  <a href="/examples/todo-api" style="display:flex;align-items:center;gap:0.4rem;text-decoration:none;color:inherit;">
    <span>🗒️ TODO API</span>
    <span aria-hidden="true">›</span>
  </a>
</div>
