# oasm-docker

This repository contains Docker configuration for running OASM platform.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. Copy the example environment file:

   ```
   cp example.env .env
   ```

2. Pull the latest Docker images:

   ```
   docker-compose pull
   ```

3. Start the services in detached mode:
   ```
   docker-compose up -d
   ```

The application will be available at:

- Web Console: http://localhost:6276
