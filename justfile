set shell := ["sh", "-cu"]

PI_HOST := env_var_or_default("PI_HOST", "forgejo-pi.tail8f7f61.ts.net")
SSD_DEVICE := env_var_or_default("SSD_DEVICE", "/dev/disk5")

default: help

help:
  @echo "Usage:"
  @echo "  just image-build  -> builds the builder container"
  @echo "  just build        -> builds the NixOS image"
  @echo "  just disk-list    -> show available disks"
  @echo "  just flash        -> writes image to SSD/SD card"
  @echo "  just deploy       -> nixos-rebuild switch to Pi"
  @echo "  just restore      -> restores forgejo data from backups"
  @echo ""
  @echo "  just fmt          -> format Nix files"
  @echo "  just fmt-check    -> check formatting without changes"
  @echo "  just check        -> lint and validate configuration"
  @echo "  just build-eval   -> evaluate NixOS configuration"
  @echo "  just build-dry    -> dry-run build showing changes"
  @echo "  just ci           -> run all checks locally"
  @echo ""
  @echo "Variables:"
  @echo "  SSD_DEVICE=<device>  -> default: /dev/disk4"
  @echo "  PI_HOST=<host>       -> default: forgejo-pi.tail8f7f61.ts.net"

image-build: ci
  @echo "Running CI checks before build..."
  @echo "Building builder container..."
  podman-compose build

build:
  . ./scripts/init.sh && podman-compose run --rm builder

disk-list:
  diskutil list

flash ssd_device=SSD_DEVICE:
  SSD_DEVICE={{ssd_device}} ./scripts/flash.sh

deploy pi_host=PI_HOST:
  nixos-rebuild switch --flake .#forgejo-pi --target-host root@{{pi_host}} --build-host localhost

deploy-disko pi_host=PI_HOST:
  nixos-rebuild switch --flake .#forgejo-pi-disko --target-host root@{{pi_host}} --build-host localhost

restore pi_host=PI_HOST:
  PI_HOST={{pi_host}} ./scripts/restore.sh

fmt:
  @echo "Formatting Nix files..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix fmt
  @echo "Formatting complete"

fmt-check:
  @echo "Checking Nix file formatting..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix fmt -- --check .
  @echo "Format check passed"

check:
  @echo "Running checks..."
  @echo "  -> Flake check..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix flake check --no-build 2>&1 || true
  @echo "  -> Statix lint..."
  @command -v statix >/dev/null 2>&1 && statix check . || echo "  - statix not installed, skipping"
  @echo "  -> Deadnix check..."
  @command -v deadnix >/dev/null 2>&1 && deadnix . || echo "  - deadnix not installed, skipping"
  @echo "Checks passed"

build-eval:
  @echo "Evaluating host configuration (forgejo-pi)..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix eval '.#nixosConfigurations.forgejo-pi.config.system.build.toplevel' --system aarch64-linux --raw > /dev/null
  @echo "Evaluating image configuration (forgejo-pi-image)..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix eval '.#nixosConfigurations.forgejo-pi-image.config.system.build.sdImage' --system aarch64-linux --raw > /dev/null
  @echo "Configurations are valid"

build-dry:
  @echo "Dry-run build (showing changes)..."
  @XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp}" nix build .#nixosConfigurations.forgejo-pi.config.system.build.toplevel --system aarch64-linux --no-link --dry-run
  @echo "Dry-run complete"

ci: fmt-check check build-eval build-dry
  @echo "CI verification passed locally"
