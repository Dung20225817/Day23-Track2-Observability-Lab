## Day 23 Track 2 — Observability Lab orchestration
##
## Quick start:
##   make setup    # one-time: pull images, create .env
##   make up       # start the 7-service stack
##   make smoke    # verify all services healthy
##   make demo     # run end-to-end demo (load + alert + trace + drift)
##   make verify   # rubric gate — exit 0 if all checkpoints pass
##   make down     # stop the stack
##   make clean    # stop + remove volumes (destructive)

SHELL := /bin/bash
COMPOSE ?= docker compose

# Cross-platform: NULL device
ifeq ($(OS),Windows_NT)
  NULL := NUL
  PYTHON := python
else
  NULL := /dev/null
  PYTHON := python3
endif

.PHONY: help setup up down restart logs smoke load alert trace drift demo verify clean lint-dashboards

help:
	@grep -E '^##|^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sed -E 's/^## ?//; s/:.*## /\t/' | column -t -s '	'

setup: ## one-time install + .env scaffold
	$(PYTHON) -c "import shutil; import os; shutil.copy('.env.example','.env') if not os.path.exists('.env') else None"
	$(PYTHON) 00-setup/pull-images.py
	$(PYTHON) 00-setup/verify-docker.py

up: ## start the stack
	$(COMPOSE) up -d
	@echo "Stack starting. Run 'make smoke' to verify (allow ~30s for first start)."

down: ## stop the stack (preserves volumes)
	$(COMPOSE) down

restart: down up ## stop + start

logs: ## tail logs from all services
	$(COMPOSE) logs -f --tail=50

smoke: ## health-check all 7 services
	@echo "Checking services..."
	@curl -fsS http://localhost:8000/healthz   > $(NULL) 2>&1 && echo "  app:           OK" || echo "  app:           FAIL"
	@curl -fsS http://localhost:9090/-/healthy > $(NULL) 2>&1 && echo "  prometheus:    OK" || echo "  prometheus:    FAIL"
	@curl -fsS http://localhost:9093/-/healthy > $(NULL) 2>&1 && echo "  alertmanager:  OK" || echo "  alertmanager:  FAIL"
	@curl -fsS http://localhost:3000/api/health > $(NULL) 2>&1 && echo "  grafana:       OK" || echo "  grafana:       FAIL"
	@curl -fsS http://localhost:3100/ready     > $(NULL) 2>&1 && echo "  loki:          OK" || echo "  loki:          FAIL"
	@curl -fsS http://localhost:16686/          > $(NULL) 2>&1 && echo "  jaeger:        OK" || echo "  jaeger:        FAIL"
	@curl -fsS http://localhost:8888/metrics    > $(NULL) 2>&1 && echo "  otel-collector: OK" || echo "  otel-collector: FAIL"
	@echo "Stack check done."

ifeq ($(OS),Windows_NT)
  LOAD_LOCUST := docker run --rm --network=day23-track2-observability-lab_obs -v "D:/Project_AI/Day23-Track2-Observability-Lab/02-prometheus-grafana/load-test:/mnt/locust" locustio/locust:latest -f /mnt/locust/locustfile.py --headless -u 10 -r 2 -t 60s --host http://app:8000
else
  LOAD_LOCUST := cd 02-prometheus-grafana/load-test && locust -f locustfile.py --headless -u 10 -r 2 -t 60s --host http://localhost:8000
endif

load: ## run baseline locust load (concurrency=10, 60s)
	$(LOAD_LOCUST)

alert: ## trigger an alert by killing the app, wait, then restore
	$(PYTHON) scripts/trigger-alert.py

trace: ## generate one traced request and print its trace_id
	@curl -sS -X POST http://localhost:8000/predict \
	  -H 'Content-Type: application/json' \
	  -d '{"prompt":"hello"}' | $(PYTHON) -c 'import json,sys; d=json.load(sys.stdin); print("trace_id:",d.get("trace_id","?"))'

drift: ## run drift detection script
	cd 04-drift-detection && $(PYTHON) scripts/drift_detect.py

demo: ## end-to-end demo (load -> alert -> trace -> drift)
	$(MAKE) load
	$(MAKE) alert
	$(MAKE) trace
	$(MAKE) drift

verify: ## rubric gate — exits 0 only if all checkpoints pass
	$(PYTHON) scripts/verify.py

lint-dashboards: ## validate Grafana dashboard JSONs
	$(PYTHON) scripts/lint-dashboards.py 02-prometheus-grafana/grafana/dashboards/*.json

clean: ## stop stack + remove volumes (DESTRUCTIVE)
	$(COMPOSE) down -v
