.PHONY: up down dev purge

up:
	@echo "Starting Spark cluster..."
	@COMPOSE_BAKE=true docker compose up -d --build

down:
	@echo "Stopping Spark cluster and cleaning up..."
	@docker compose down

dev:
	@echo "Starting Spark cluster in development mode..."
	@docker exec -it spark-master bash

purge:
	@echo "Stopping Spark cluster and cleaning up..."
	@docker compose down --rmi all
	@rm -rf data/output && \
		find warehouse/ -mindepth 1 -maxdepth 1 -not -name "*.ipynb" -exec rm -rf {} +
