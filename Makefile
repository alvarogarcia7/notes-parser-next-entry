.PHONY: help up down status nats-up nats-down listener-time listener-training listener-hn listener-next writer-time writer-training writer-hn writer-next publisher clean logs

# Colors for output
GREEN = \033[0;32m
BLUE = \033[0;34m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

# Configuration
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --no-builtin-rules

# Load environment from .env if it exists
ifneq (,$(wildcard .env))
	include .env
	export NATS_URL
	export NATS_PORT
	export CERTS_DIR
endif

# Default values
NATS_URL ?= tls://localhost:4222
NATS_PORT ?= 4222
CERTS_DIR ?= $(shell pwd)/certs

# Container and process names
NATS_CONTAINER := nats-server
PIDS_FILE := ./.make-pids

# Help target
help:
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║             NATS Pipeline Control Plane                    ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(GREEN)System Control:$(NC)"
	@echo "  $(YELLOW)up$(NC)              Start all components (NATS + listeners + writers + publisher)"
	@echo "  $(YELLOW)down$(NC)            Stop all running components"
	@echo "  $(YELLOW)status$(NC)          Show status of all components"
	@echo "  $(YELLOW)logs$(NC)            Show logs from all background processes"
	@echo "  $(YELLOW)clean$(NC)           Remove all process files and cleanup"
	@echo ""
	@echo "$(GREEN)NATS Server:$(NC)"
	@echo "  $(YELLOW)nats-up$(NC)         Start NATS server in Docker"
	@echo "  $(YELLOW)nats-down$(NC)       Stop NATS server"
	@echo ""
	@echo "$(GREEN)Listeners (depend on nats-up):$(NC)"
	@echo "  $(YELLOW)listener-time$(NC)     Start time entry listener"
	@echo "  $(YELLOW)listener-training$(NC) Start training listener"
	@echo "  $(YELLOW)listener-hn$(NC)       Start HackerNews listener"
	@echo "  $(YELLOW)listener-next$(NC)     Start Next entry listener"
	@echo ""
	@echo "$(GREEN)Writers:$(NC)"
	@echo "  $(YELLOW)writer-time$(NC)       Start time entry writer"
	@echo "  $(YELLOW)writer-training$(NC)   Start training writer"
	@echo "  $(YELLOW)writer-hn$(NC)         Start HackerNews writer"
	@echo "  $(YELLOW)writer-next$(NC)       Start Next entry writer"
	@echo ""
	@echo "$(GREEN)Publisher:$(NC)"
	@echo "  $(YELLOW)publisher$(NC)        Start Google Keep notes publisher"
	@echo ""
	@echo "$(GREEN)Configuration:$(NC)"
	@echo "  NATS_URL: $(NATS_URL)"
	@echo "  NATS_PORT: $(NATS_PORT)"
	@echo "  CERTS_DIR: $(CERTS_DIR)"
	@echo ""

# ============================================================================
# NATS Server Targets
# ============================================================================

nats-up:
	@echo "$(GREEN)▶$(NC) Starting NATS server..."
	@if docker ps --format "{{.Names}}" | grep -q "^$(NATS_CONTAINER)$$"; then \
		echo "$(YELLOW)⚠$(NC) NATS container already running"; \
	else \
		docker run -d \
			--name $(NATS_CONTAINER) \
			-p $(NATS_PORT):4222 \
			-v $(CERTS_DIR):/certs:ro \
			-v $(shell pwd)/nats-server.conf:/etc/nats/nats-server.conf:ro \
			nats:latest \
			-c /etc/nats/nats-server.conf \
		&& echo "$(GREEN)✓$(NC) NATS server started on port $(NATS_PORT)"; \
	fi
	@sleep 2

nats-down:
	@echo "$(GREEN)▶$(NC) Stopping NATS server..."
	@docker stop $(NATS_CONTAINER) 2>/dev/null || true
	@docker rm $(NATS_CONTAINER) 2>/dev/null || true
	@echo "$(GREEN)✓$(NC) NATS server stopped"

nats-status:
	@if docker ps --format "{{.Names}}" | grep -q "^$(NATS_CONTAINER)$$"; then \
		echo "$(GREEN)✓$(NC) NATS server is running"; \
	else \
		echo "$(RED)✗$(NC) NATS server is not running"; \
	fi

# ============================================================================
# Listener Targets (depend on nats-up)
# ============================================================================

listener-time: nats-up
	@echo "$(GREEN)▶$(NC) Starting time entry listener..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/time-entry-notes-parser/.venv/bin/activate && \
		python3 $(shell pwd)/time-entry-notes-parser/nats_time_listener.py > /tmp/listener-time.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/listener-time.pid && \
		echo "$(GREEN)✓$(NC) Time entry listener started (PID: $$!)"

listener-training: nats-up
	@echo "$(GREEN)▶$(NC) Starting training listener..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/training-parser-antlr4/.venv/bin/activate && \
		python3 $(shell pwd)/training-parser-antlr4/nats_training_listener.py > /tmp/listener-training.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/listener-training.pid && \
		echo "$(GREEN)✓$(NC) Training listener started (PID: $$!)"

listener-hn: nats-up
	@echo "$(GREEN)▶$(NC) Starting HackerNews listener..."
	@mkdir -p $(PIDS_FILE)
	@echo "$(YELLOW)ℹ$(NC) HackerNews listener not yet implemented"

listener-next: nats-up
	@echo "$(GREEN)▶$(NC) Starting next entry listener..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/notes-parser-next-entry/.venv/bin/activate && \
		python3 $(shell pwd)/notes-parser-next-entry/nats_next_listener.py > /tmp/listener-next.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/listener-next.pid && \
		echo "$(GREEN)✓$(NC) Next entry listener started (PID: $$!)"

# ============================================================================
# Writer Targets
# ============================================================================

writer-time: nats-up
	@echo "$(GREEN)▶$(NC) Starting time entry writer..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/time-entry-notes-parser/.venv/bin/activate && \
		python3 $(shell pwd)/time-entry-notes-parser/nats_writer.py > /tmp/writer-time.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/writer-time.pid && \
		echo "$(GREEN)✓$(NC) Time entry writer started (PID: $$!)"

writer-training: nats-up
	@echo "$(GREEN)▶$(NC) Starting training writer..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/training-parser-antlr4/.venv/bin/activate && \
		python3 $(shell pwd)/training-parser-antlr4/nats_writer.py > /tmp/writer-training.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/writer-training.pid && \
		echo "$(GREEN)✓$(NC) Training writer started (PID: $$!)"

writer-hn: nats-up
	@echo "$(GREEN)▶$(NC) Starting HackerNews writer..."
	@mkdir -p $(PIDS_FILE)
	@echo "$(YELLOW)ℹ$(NC) HackerNews writer not yet implemented"

writer-next: nats-up
	@echo "$(GREEN)▶$(NC) Starting next entry writer..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/notes-parser-next-entry/.venv/bin/activate && \
		python3 $(shell pwd)/notes-parser-next-entry/nats_writer.py > /tmp/writer-next.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/writer-next.pid && \
		echo "$(GREEN)✓$(NC) Next entry writer started (PID: $$!)"

# ============================================================================
# Publisher Target
# ============================================================================

publisher: nats-up
	@echo "$(GREEN)▶$(NC) Starting Google Keep notes publisher..."
	@mkdir -p $(PIDS_FILE)
	@source $(shell pwd)/google-keep-notes-parser/.venv/bin/activate && \
		python3 $(shell pwd)/google-keep-notes-parser/nats_publisher.py > /tmp/publisher.log 2>&1 & \
		echo $$! > $(PIDS_FILE)/publisher.pid && \
		echo "$(GREEN)✓$(NC) Publisher started (PID: $$!)"

# ============================================================================
# System Control Targets
# ============================================================================

up: nats-up listener-time listener-training listener-next writer-time writer-training writer-next publisher
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║                    System Started                          ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Active Components:$(NC)"
	@echo "  $(GREEN)✓$(NC) NATS server (port $(NATS_PORT))"
	@echo "  $(GREEN)✓$(NC) Time entry listener & writer"
	@echo "  $(GREEN)✓$(NC) Training listener & writer"
	@echo "  $(GREEN)✓$(NC) Next entry listener & writer"
	@echo "  $(GREEN)✓$(NC) Google Keep publisher"
	@echo ""
	@echo "$(GREEN)Check logs:$(NC)"
	@echo "  make logs"
	@echo ""
	@echo "$(GREEN)Stop system:$(NC)"
	@echo "  make down"
	@echo ""

down:
	@echo "$(GREEN)▶$(NC) Stopping all components..."
	@echo ""
	@echo "$(YELLOW)Stopping listeners...$(NC)"
	@for pid_file in $(PIDS_FILE)/listener-*.pid; do \
		if [ -f "$$pid_file" ]; then \
			pid=$$(cat $$pid_file); \
			kill $$pid 2>/dev/null || true; \
			rm -f $$pid_file; \
		fi; \
	done
	@echo "$(GREEN)✓$(NC) Listeners stopped"
	@echo ""
	@echo "$(YELLOW)Stopping writers...$(NC)"
	@for pid_file in $(PIDS_FILE)/writer-*.pid; do \
		if [ -f "$$pid_file" ]; then \
			pid=$$(cat $$pid_file); \
			kill $$pid 2>/dev/null || true; \
			rm -f $$pid_file; \
		fi; \
	done
	@echo "$(GREEN)✓$(NC) Writers stopped"
	@echo ""
	@echo "$(YELLOW)Stopping publisher...$(NC)"
	@if [ -f "$(PIDS_FILE)/publisher.pid" ]; then \
		kill $$(cat $(PIDS_FILE)/publisher.pid) 2>/dev/null || true; \
		rm -f $(PIDS_FILE)/publisher.pid; \
	fi
	@echo "$(GREEN)✓$(NC) Publisher stopped"
	@echo ""
	@echo "$(YELLOW)Stopping NATS server...$(NC)"
	@$(MAKE) nats-down
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║                    System Stopped                          ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""

# ============================================================================
# Status and Monitoring
# ============================================================================

status:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)                   System Status                            $(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BLUE)NATS Server:$(NC)"
	@$(MAKE) nats-status
	@echo ""
	@echo "$(BLUE)Listeners:$(NC)"
	@for pid_file in $(PIDS_FILE)/listener-*.pid; do \
		if [ -f "$$pid_file" ]; then \
			pid=$$(cat $$pid_file); \
			name=$$(basename $$pid_file .pid); \
			if kill -0 $$pid 2>/dev/null; then \
				echo "  $(GREEN)✓$(NC) $$name (PID: $$pid)"; \
			else \
				echo "  $(RED)✗$(NC) $$name (PID: $$pid) - DEAD"; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Writers:$(NC)"
	@for pid_file in $(PIDS_FILE)/writer-*.pid; do \
		if [ -f "$$pid_file" ]; then \
			pid=$$(cat $$pid_file); \
			name=$$(basename $$pid_file .pid); \
			if kill -0 $$pid 2>/dev/null; then \
				echo "  $(GREEN)✓$(NC) $$name (PID: $$pid)"; \
			else \
				echo "  $(RED)✗$(NC) $$name (PID: $$pid) - DEAD"; \
			fi; \
		fi; \
	done
	@echo ""
	@echo "$(BLUE)Publisher:$(NC)"
	@if [ -f "$(PIDS_FILE)/publisher.pid" ]; then \
		pid=$$(cat $(PIDS_FILE)/publisher.pid); \
		if kill -0 $$pid 2>/dev/null; then \
			echo "  $(GREEN)✓$(NC) publisher (PID: $$pid)"; \
		else \
			echo "  $(RED)✗$(NC) publisher (PID: $$pid) - DEAD"; \
		fi; \
	else \
		echo "  $(RED)✗$(NC) Not started"; \
	fi
	@echo ""

logs:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)                   System Logs                              $(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Time Entry:$(NC)"
	@echo "  Listener: tail -f /tmp/listener-time.log"
	@echo "  Writer:   tail -f /tmp/writer-time.log"
	@echo ""
	@echo "$(YELLOW)Training:$(NC)"
	@echo "  Listener: tail -f /tmp/listener-training.log"
	@echo "  Writer:   tail -f /tmp/writer-training.log"
	@echo ""
	@echo "$(YELLOW)Next Entry:$(NC)"
	@echo "  Listener: tail -f /tmp/listener-next.log"
	@echo "  Writer:   tail -f /tmp/writer-next.log"
	@echo ""
	@echo "$(YELLOW)Publisher:$(NC)"
	@echo "  tail -f /tmp/publisher.log"
	@echo ""

# ============================================================================
# Cleanup
# ============================================================================

clean: down
	@echo "$(GREEN)▶$(NC) Cleaning up..."
	@rm -rf $(PIDS_FILE)
	@rm -f /tmp/listener-*.log /tmp/writer-*.log /tmp/publisher.log
	@echo "$(GREEN)✓$(NC) Cleanup complete"

# ============================================================================
# Development Targets
# ============================================================================

install:
	@bash install-mac.sh

env-check:
	@echo "$(BLUE)Environment Configuration:$(NC)"
	@echo "  NATS_URL: $(NATS_URL)"
	@echo "  NATS_PORT: $(NATS_PORT)"
	@echo "  CERTS_DIR: $(CERTS_DIR)"
	@if [ -f "$(CERTS_DIR)/rootCA.pem" ]; then \
		echo "  $(GREEN)✓$(NC) Certificates found"; \
	else \
		echo "  $(RED)✗$(NC) Certificates not found"; \
	fi

setup: env-check
	@if [ ! -d "time-entry-notes-parser/.venv" ]; then \
		echo "$(YELLOW)Setting up virtual environments...$(NC)"; \
		$(MAKE) install; \
	fi

# Default target
.DEFAULT_GOAL := help
