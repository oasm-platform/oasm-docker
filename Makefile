
pull:
	docker compose pull

run:
	docker compose up -d --force-recreate --remove-orphans

down:
	docker compose down