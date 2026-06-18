.PHONY: all pull run update update-main down clean pull-latest-commit

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