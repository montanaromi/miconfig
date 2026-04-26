PYTHON := python3

.PHONY: setup guest install sync help

help:
	@echo "Usage:"
	@echo "  make setup     Provision a fresh machine (packages, languages, shell)"
	@echo "  make guest     Create a guest dev account (agent-<name>)"
	@echo "  make install   Symlink configs into their OS-specific locations"
	@echo "  make sync      Update all submodules (SSH URL rewrite + restore)"

setup:
	bash setup.sh

guest:
	bash guest.sh

install:
	$(PYTHON) install.py

sync:
	$(PYTHON) sync-submodules.py
