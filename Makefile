up:
	COMPOSE_BAKE=true docker compose up -d --build

down:
	docker compose down --rmi all
	rm -rf data/output && \
		find warehouse/ -mindepth 1 -maxdepth 1 -not -name "*.ipynb" -exec rm -rf {} +

dev:
	docker exec -it spark-master bash
