# Top-level Makefile for project orchestration
# Delegates to nats/ for infrastructure control

NATS_DIR := nats
PARSERS_DIR := parsers

.PHONY: help up down status logs clean install env-check setup
.PHONY: nats-up nats-down nats-status
.PHONY: listener listener-time listener-training listener-hn listener-next
.PHONY: writer writer-time writer-training writer-hn writer-next
.PHONY: publisher notes-exporter-publisher
.PHONY: time training hn next
.PHONY: update-parsers-check update-parsers-all update-parser-time update-parser-training update-parser-hn update-parser-next
.PHONY: update-time update-training update-hn update-next
.PHONY: parser-status parser-versions
.PHONY: start-all-parsers

help:
	@echo "NATS Pipeline Control Plane"
	@echo ""
	@echo "System Control:"
	@echo "  make up              - Start entire system"
	@echo "  make down            - Stop entire system"
	@echo "  make status          - Show system status"
	@echo "  make logs            - Show log locations"
	@echo "  make clean           - Stop and clean up"
	@echo ""
	@echo "Setup:"
	@echo "  make install         - Install and configure system"
	@echo "  make env-check       - Check environment"
	@echo "  make setup           - Full setup"
	@echo ""
	@echo "Parser Bundles (start nats + listener + writer):"
	@echo "  make time            - Start time entry parser bundle"
	@echo "  make training        - Start training parser bundle"
	@echo "  make hn              - Start HackerNews parser bundle"
	@echo "  make next            - Start next entry parser bundle"
	@echo ""
	@echo "Individual Components:"
	@echo "  make listener        - Start all listeners"
	@echo "  make writer          - Start all writers"
	@echo "  make publisher              - Start Google Keep publisher"
	@echo "  make notes-exporter-publisher - Start Apple Notes (notes-exporter) publisher"
	@echo ""
	@echo "Parser Updates:"
	@echo "  make update-parsers-check  - Check all parsers for updates"
	@echo "  make update-parsers-all    - Update all parsers"
	@echo "  make parser-status         - Show parser versions"
	@echo ""
	@echo "Run 'make -C nats help' for detailed infrastructure targets"

# Delegate to nats/ Makefile for all system control
up:
	@$(MAKE) -C $(NATS_DIR) up

down:
	@$(MAKE) -C $(NATS_DIR) down

status:
	@$(MAKE) -C $(NATS_DIR) status

logs:
	@$(MAKE) -C $(NATS_DIR) logs

clean:
	@$(MAKE) -C $(NATS_DIR) clean

install:
	@$(MAKE) -C $(NATS_DIR) install

env-check:
	@$(MAKE) -C $(NATS_DIR) env-check

setup:
	@$(MAKE) -C $(NATS_DIR) setup

# NATS targets
nats-up:
	@$(MAKE) -C $(NATS_DIR) nats-up

nats-down:
	@$(MAKE) -C $(NATS_DIR) nats-down

nats-status:
	@$(MAKE) -C $(NATS_DIR) nats-status

# Listener targets
listener: listener-time listener-training listener-next

listener-time:
	@$(MAKE) -C $(NATS_DIR) listener-time

listener-training:
	@$(MAKE) -C $(NATS_DIR) listener-training

listener-hn:
	@$(MAKE) -C $(NATS_DIR) listener-hn

listener-next:
	@$(MAKE) -C $(NATS_DIR) listener-next

# Writer targets
writer: writer-time writer-training writer-next

writer-time:
	@$(MAKE) -C $(NATS_DIR) writer-time

writer-training:
	@$(MAKE) -C $(NATS_DIR) writer-training

writer-hn:
	@$(MAKE) -C $(NATS_DIR) writer-hn

writer-next:
	@$(MAKE) -C $(NATS_DIR) writer-next

# Publisher
publisher:
	@$(MAKE) -C $(NATS_DIR) publisher

notes-exporter-publisher:
	@$(MAKE) -C $(NATS_DIR) notes-exporter-publisher

# Parser bundles
time: nats-up listener-time writer-time

training: nats-up listener-training writer-training

hn: nats-up listener-hn writer-hn

next: nats-up listener-next writer-next

# Parser updates
update-parsers-check:
	@$(MAKE) -C $(NATS_DIR) update-parsers-check

update-parsers-all:
	@$(MAKE) -C $(NATS_DIR) update-parsers-all

update-parser-time:
	@$(MAKE) -C $(NATS_DIR) update-parser-time

update-parser-training:
	@$(MAKE) -C $(NATS_DIR) update-parser-training

update-parser-hn:
	@$(MAKE) -C $(NATS_DIR) update-parser-hn

update-parser-next:
	@$(MAKE) -C $(NATS_DIR) update-parser-next

update-time:
	@$(MAKE) -C $(NATS_DIR) update-time

update-training:
	@$(MAKE) -C $(NATS_DIR) update-training

update-hn:
	@$(MAKE) -C $(NATS_DIR) update-hn

update-next:
	@$(MAKE) -C $(NATS_DIR) update-next

# Parser status
parser-status:
	@$(MAKE) -C $(NATS_DIR) parser-status

parser-versions:
	@$(MAKE) -C $(NATS_DIR) parser-versions

# Colocated parser management
start-all-parsers:
	@if [ -f $(PARSERS_DIR)/start-all.sh ]; then \
		bash $(PARSERS_DIR)/start-all.sh; \
	else \
		echo "No parsers colocated in $(PARSERS_DIR)"; \
	fi
