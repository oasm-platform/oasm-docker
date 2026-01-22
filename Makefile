.PHONY: all pull run update update-main update-assistant down clean

# Default target - runs the full system
all: pull run

# Pull the latest images
pull:
	docker compose pull
	docker compose -f docker-compose-assistant.yml pull

# Run services (without pulling)
run:
	docker compose up -d --force-recreate --remove-orphans
	docker compose -f docker-compose-assistant.yml up -d --force-recreate --remove-orphans

# Update: pull latest images and restart services
update: pull down run

# Update only main services
update-main:
	docker compose pull
	docker compose down
	docker compose up -d --force-recreate --remove-orphans

# Update only assistant services  
update-assistant:
	docker compose -f docker-compose-assistant.yml pull
	docker compose -f docker-compose-assistant.yml down
	docker compose -f docker-compose-assistant.yml up -d --force-recreate --remove-orphans

# Stop all services
down:
	docker compose down --remove-orphans
	docker compose -f docker-compose-assistant.yml down --remove-orphans

# Clean up everything (stop services and remove volumes)
clean: down
	docker compose down -v --remove-orphans
	docker compose -f docker-compose-assistant.yml down -v --remove-orphans