.PHONY: all pull run update update-main down clean pull-latest-commit

# The worker runs as a non-root user and needs the group that owns the host
# Docker socket to start connector containers. DOCKER_GID from the environment
# or .env wins; otherwise detect it (GNU stat, then BSD/macOS stat). Empty falls
# back to the compose default of 0 (Docker Desktop).
DOCKER_GID ?= $(or $(shell sed -n 's/^DOCKER_GID=//p' .env 2>/dev/null),$(shell stat -c '%g' /var/run/docker.sock 2>/dev/null || stat -f '%g' /var/run/docker.sock 2>/dev/null))
export DOCKER_GID

# Default target - runs the full system
all: pull-latest-commit pull run

# Pull the latest images
pull:
	docker compose pull

# Run services (without pulling)
run:
	docker compose up -d

# Update: pull latest images and restart services
update: pull-latest-commit pull down run

# Update only main services
update-main:
	docker compose pull
	docker compose down
	docker compose up -d

# Pull latest commit from main repository
pull-latest-commit:
	git pull

# Stop all services
down:
	docker compose down --remove-orphans