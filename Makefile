PYTHON := python3

.PHONY: install sync help

help:
	@echo "Usage:"
	@echo "  make install   Symlink configs into their OS-specific locations"
	@echo "  make sync      Update all submodules (SSH URL rewrite + restore)"

install:
	$(PYTHON) install.py

sync:
	$(PYTHON) sync-submodules.py
