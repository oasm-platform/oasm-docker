# Open Attack Surface Management (OASM) Platform

## 🛠 Prerequisites

- Docker
- Docker Compose
- Make
- Minimum System Requirements:
  - 4 CPU cores
  - 4GB RAM
  - 20GB free disk space

## 🚀 Try it now

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/oasm-platform/oasm-docker)

## ⚡ Quick Start

1. **Prepare configuration**:

   ```bash
   cp .env.example .env
   ```

2. **Pull and Start**:

   ```bash
   docker compose pull
   docker compose up -d
   ```

3. **(Optional) AI Assistant**:
   ```bash
   docker compose -f docker-compose-assistant.yml up -d
   ```

## 🔗 Access the Platform

Web Console: http://localhost:6276

## 📋 Configuration

Edit the `.env` file to customize your deployment:

- `IMAGE_TAG`: Docker image version (default: `latest`)
- `OASM_CLOUD_APIKEY`: API key for cloud integration
- `POSTGRES_*`: Database connection settings
- `REDIS_PASSWORD`: Redis authentication password
- `LLM_*`: AI assistant configuration (if enabled)

## 🔧 Useful Commands

```bash
# View all logs
docker compose logs -f

# Stop all services
docker compose down

# Scale worker instances
docker compose up --scale oasm-worker=5
```

## 🛠️ Make Commands

| Command | Description |
|---------|-------------|
| `make` or `make all` | Default target - pulls latest images and runs the full system |
| `make pull` | Pull the latest images from both docker-compose files (main and assistant) |
| `make run` | Run services (without pulling new images) |
| `make update` | Pull new images and restart both compose files (main and assistant) |
| `make update-main` | Update only main services |
| `make update-assistant` | Update only assistant services (assistant, searxng) |
| `make down` | Stop all services |
| `make clean` | Clean up everything (stop services and remove volumes) |

---

**Note**: This platform is designed for authorized security testing only. Always ensure you have proper authorization before scanning systems you don't own.