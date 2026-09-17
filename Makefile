STYLUA ?= stylua
LUACHECK ?= luacheck
LUA ?= lua
NODE ?= node
PYTHON ?= python3

# Explicit paths avoid formatting personal configuration or unrelated local files.
LUA_PATHS = init.lua config.lua config.example.lua modules tests
.DEFAULT_GOAL := help

.PHONY: help format format-check lint test-unit test-panel test-snapshots test check

help:
	@printf '%s\n' \
	  'make format         Format Lua with StyLua and verify the AST' \
	  'make format-check   Check formatting without changing files' \
	  'make lint           Analyze Lua with Luacheck' \
	  'make test-unit      Run Lua tests with Hammerspoon test doubles' \
	  'make test-panel     Test localized HTML panel behavior' \
	  'make test-snapshots Run offline RDS script contract tests' \
	  'make test           Run all offline tests' \
	  'make check          Check formatting, lint and all tests'

format:
	$(STYLUA) --verify $(LUA_PATHS) .luacheckrc

format-check:
	$(STYLUA) --check $(LUA_PATHS) .luacheckrc

lint:
	$(LUACHECK) $(LUA_PATHS)

test-unit:
	@set -e; for file in tests/*_test.lua; do $(LUA) "$$file"; done

test-panel:
	LUA="$(LUA)" $(NODE) tests/panel_i18n_test.js

test-snapshots:
	$(PYTHON) tests/snapshot_test.py

test: test-unit test-panel test-snapshots

check: format-check lint test
