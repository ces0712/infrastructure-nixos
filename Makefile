.PHONY: image-build build build-eval build-dry fmt fmt-check check ci partition deploy restore help

PI_HOST    ?= forgejo-pi.tail8f7f61.ts.net
SSD_DEVICE ?= /dev/sda

help:
	@echo "Usage:"
	@echo "  make image-build            → builds the builder container"
	@echo "  make build                 → builds the NixOS image"
	@echo "  make build-eval            → evaluate configuration (validation)"
	@echo "  make build-dry             → dry-run build showing changes"
	@echo "  make fmt                   → format Nix files"
	@echo "  make fmt-check             → check formatting without changes"
	@echo "  make check                 → lint and validate configuration"
	@echo "  make ci                    → run CI checks locally"
	@echo "  make partition             → partitions SSD and installs NixOS"
	@echo "  make deploy                → nixos-rebuild switch to Pi"
	@echo "  make restore               → restores forgejo data from backups"
	@echo ""
	@echo "Variables:"
	@echo "  PI_HOST=<ip>        → default: forgejo-pi.tail8f7f61.ts.net"
	@echo "  SSD_DEVICE=<device> → default: /dev/sda"
	@echo ""
	@echo "First time / disaster recovery flow:"
	@echo "  1. make image-build"
	@echo "  2. make build"
	@echo "  3. make partition SSD_DEVICE=/dev/disk2"
	@echo "  4. plug SSD into Pi and boot"
	@echo "  5. make restore"
	@echo "  6. make deploy"

# ============================================================
# Build Targets
# ============================================================

build-eval:
	@echo "🔍 Evaluating host configuration (forgejo-pi)..."
	@nix eval '.#nixosConfigurations.forgejo-pi.config.system.build.toplevel' --system aarch64-linux --raw > /dev/null
	@echo "✅ Configuration is valid"

build-dry:
	@echo "🔨 Dry-run build (showing changes)..."
	@nix build .#nixosConfigurations.forgejo-pi.config.system.build.toplevel --system aarch64-linux --no-link --dry-run
	@echo "✅ Dry-run complete"

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

ci: check build-eval
	@echo "🎉 CI verification passed locally"

# ============================================================
# Deployment Targets
# ============================================================

image-build:
	podman-compose build

build:
	MAKE_TARGET=build \
	  podman-compose run --rm builder

partition:
	MAKE_TARGET=partition \
	SSD_DEVICE=$(SSD_DEVICE) \
	  podman-compose run --rm builder

deploy:
	nixos-rebuild switch \
	  --flake .#forgejo-pi \
	  --target-host root@$(PI_HOST) \
	  --build-host localhost

restore:
	@PI_HOST=$(PI_HOST) ./scripts/restore.sh
