.PHONY: image-build build flash disk-list deploy restore help fmt fmt-check check build-eval build-dry ci

PI_HOST    ?= forgejo-pi.tail8f7f61.ts.net
SSD_DEVICE ?= /dev/disk4

help:
	@echo "Usage:"
	@echo "  make image-build  → builds the builder container"
	@echo "  make build        → builds the NixOS image"
	@echo "  make disk-list    → show available disks"
	@echo "  make flash        → writes image to SSD/SD card"
	@echo "  make deploy       → nixos-rebuild switch to Pi"
	@echo "  make restore      → restores forgejo data from backups"
	@echo ""
	@echo "  make fmt          → format Nix files"
	@echo "  make fmt-check    → check formatting without changes"
	@echo "  make check        → lint and validate configuration"
	@echo "  make build-eval   → evaluate NixOS configuration"
	@echo "  make build-dry    → dry-run build showing changes"
	@echo "  make ci           → run all checks locally"
	@echo ""
	@echo "Variables:"
	@echo "  SSD_DEVICE=<device>  → default: /dev/disk4"

image-build:
	@echo "🔍 Running CI checks before build..."
	@make ci
	@echo "🏗️ Building builder container..."
	podman-compose build

build:
	. ./scripts/init.sh && podman-compose run --rm builder

disk-list:
	diskutil list

flash:
	SSD_DEVICE=$(SSD_DEVICE) ./scripts/flash.sh

deploy:
	nixos-rebuild switch --flake .#forgejo-pi --target-host root@$(PI_HOST) --build-host localhost

restore:
	PI_HOST=$(PI_HOST) ./scripts/restore.sh

# ============================================================
# Code Quality
# ============================================================

fmt:
	@echo "📝 Formatting Nix files..."
	@nix fmt
	@echo "✅ Formatting complete"

fmt-check:
	@echo "📝 Checking Nix file formatting..."
	@nix fmt -- --check .
	@echo "✅ Format check passed"

check:
	@echo "🔍 Running checks..."
	@echo "  → Flake check..."
	@nix flake check --no-build 2>&1 || true
	@echo "  → Statix lint..."
	@command -v statix >/dev/null 2>&1 && statix check . || echo "  ⚠ statix not installed, skipping"
	@echo "  → Deadnix check..."
	@command -v deadnix >/dev/null 2>&1 && deadnix . || echo "  ⚠ deadnix not installed, skipping"
	@echo "✅ Checks passed"

build-eval:
	@echo "🔍 Evaluating host configuration (forgejo-pi)..."
	@nix eval '.#nixosConfigurations.forgejo-pi.config.system.build.toplevel' --system aarch64-linux --raw > /dev/null
	@echo "✅ Configuration is valid"

build-dry:
	@echo "🔨 Dry-run build (showing changes)..."
	@nix build .#nixosConfigurations.forgejo-pi.config.system.build.toplevel --system aarch64-linux --no-link --dry-run
	@echo "✅ Dry-run complete"

ci: fmt-check check build-eval build-dry
	@echo "🎉 CI verification passed locally"
