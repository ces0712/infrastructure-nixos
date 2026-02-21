.PHONY: image-build build partition deploy restore help

PI_HOST    ?= forgejo-pi.tail8f7f61.ts.net
SSD_DEVICE ?= /dev/sda

help:
	@echo "Usage:"
	@echo "  make image-build            → builds the builder container"
	@echo "  make build                  → builds the NixOS image"
	@echo "  make partition              → partitions SSD and installs NixOS"
	@echo "  make deploy                 → nixos-rebuild switch to Pi"
	@echo "  make restore                → restores forgejo data from backups"
	@echo ""
	@echo "Variables:"
	@echo "  PI_HOST=<ip>        → default: forgejo-pi.local"
	@echo "  SSD_DEVICE=<device> → default: /dev/sda"
	@echo ""
	@echo "First time / disaster recovery flow:"
	@echo "  1. make image-build"
	@echo "  2. make build"
	@echo "  3. make partition SSD_DEVICE=/dev/disk2"
	@echo "  4. plug SSD into Pi and boot"
	@echo "  5. make restore"
	@echo "  6. make deploy"

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
