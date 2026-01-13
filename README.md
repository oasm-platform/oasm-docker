# oasm-docker

This repository contains Docker configuration for running the **Open Attack Surface Management (OASM)** platform.

## 🛠 Prerequisites

- Docker
- Docker Compose

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

## 🔗 The application will be available at:

Web Console: http://localhost:6276
