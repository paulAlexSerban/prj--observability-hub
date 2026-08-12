# Phase 0 local observability stack (Grafana + Loki + Alloy + S3 log sync)

COMPOSE_FILE := infrastructure/local/docker-compose.local.yml
ENV_FILE := infrastructure/local/.env
COMPOSE := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

.PHONY: compose_up compose_down compose_down_clean compose_ps compose_logs help

help:
	@echo "Targets:"
	@echo "  compose_up         Start local stack (Grafana http://127.0.0.1:3000)"
	@echo "  compose_down       Stop stack (keep volumes)"
	@echo "  compose_down_clean Stop stack and remove volumes"
	@echo "  compose_ps         Show running services"
	@echo "  compose_logs       Tail compose logs"
	@echo ""
	@echo "Requires $(ENV_FILE) (copy from .env.example and fill AWS keys)."

# Start stack (detached). Fails clearly if .env is missing.
compose_up:
	@test -f $(ENV_FILE) || (echo "Missing $(ENV_FILE) — cp infrastructure/local/.env.example $(ENV_FILE) and fill AWS keys"; exit 1)
	$(COMPOSE) up -d

compose_down:
	$(COMPOSE) down

compose_down_clean:
	$(COMPOSE) down -v

compose_ps:
	$(COMPOSE) ps

compose_logs:
	$(COMPOSE) logs -f --tail=100
