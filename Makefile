.PHONY: sync test install clean help listener-next writer-next

sync:
	uv sync

test: sync
	uv run pytest tests/ -v

install: sync

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf build/ dist/ *.egg-info/

listener-next: sync
	uv run python nats/nats_next_listener.py

writer-next: sync
	uv run python nats/nats_writer.py

help:
	@echo "Next Entry Parser"
	@echo ""
	@echo "Build & Test:"
	@echo "  make sync          - Install dependencies using uv"
	@echo "  make test          - Run pytest tests"
	@echo "  make install       - Install dependencies"
	@echo "  make clean         - Clean up cache and build artifacts"
	@echo ""
	@echo "Components:"
	@echo "  make listener-next - Start next entry listener"
	@echo "  make writer-next   - Start next entry writer"
