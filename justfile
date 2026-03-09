set shell := ["sh", "-cu"]

PI_HOST := env_var_or_default("PI_HOST", "forgejo-pi.tail8f7f61.ts.net")
SSD_DEVICE := env_var_or_default("SSD_DEVICE", "/dev/disk4")
GOLDEN_DEVICE := env_var_or_default("GOLDEN_DEVICE", "/dev/disk4")
GOLDEN_IMAGE := env_var_or_default("GOLDEN_IMAGE", "")
BOOTSTRAP_USER := env_var_or_default("BOOTSTRAP_USER", "root")
IDENTITY_FILE := env_var_or_default("IDENTITY_FILE", "")
DEPLOY_USER := env_var_or_default("DEPLOY_USER", "nixos")
SOPS_AGE_KEY_FILE := env_var_or_default("SOPS_AGE_KEY_FILE", "")
SOPS_AGE_KEY := env_var_or_default("SOPS_AGE_KEY", "")
SOPS_AGE_KEY_PASS_ENTRY := env_var_or_default("SOPS_AGE_KEY_PASS_ENTRY", "sops/age-key")
DEPLOY_MODE := env_var_or_default("DEPLOY_MODE", "auto")
DEPLOY_REBOOT := env_var_or_default("DEPLOY_REBOOT", "1")
BOOTSTRAP_POWEROFF := env_var_or_default("BOOTSTRAP_POWEROFF", "1")
REMOTE_SSD_DEVICE := env_var_or_default("REMOTE_SSD_DEVICE", "/dev/sda")
ROOT_SIZE_GIB := env_var_or_default("ROOT_SIZE_GIB", "200")

default: help

help:
  @echo "Usage:"
  @echo "  just image-build  -> builds the builder container"
  @echo "  just build        -> builds the shared SD/SSD bootstrap image"
  @echo "  just disk-list    -> show available disks"
  @echo "  just flash        -> thin local wrapper around diskutil + dd"
  @echo "  just boot-source  -> shows whether the Pi is booted from SD or SSD"
  @echo "  just validate     -> verifies the SSD runtime is healthy"
  @echo "  just bootstrap    -> from SD boot, resize flashed SSD root and create the data partition"
  @echo "  just deploy       -> deploy the Forgejo runtime to Pi (remote build)"
  @echo "  just restore      -> restores forgejo data from backups"
  @echo ""
  @echo "Recovery / optional:"
  @echo "  just golden-create -> capture compressed golden SSD image"
  @echo "  just golden-restore -> restore golden image back to SSD"
  @echo ""
  @echo "  just fmt          -> format Nix files"
  @echo "  just fmt-check    -> check formatting without changes"
  @echo "  just check        -> lint and validate configuration"
  @echo "  just build-eval   -> evaluate NixOS configuration"
  @echo "  just build-dry    -> dry-run build showing changes"
  @echo "  just clean-cache  -> clear podman nix cache volume"
  @echo "  just ci           -> run all checks locally"
  @echo ""
  @echo "Variables:"
  @echo "  SSD_DEVICE=<device>  -> default: /dev/disk4"
  @echo "  GOLDEN_DEVICE=<device> -> default: /dev/disk4"
  @echo "  GOLDEN_IMAGE=<path> -> required for restore, optional for create"
  @echo "  PI_HOST=<host>       -> default: forgejo-pi.tail8f7f61.ts.net"
  @echo "  BOOTSTRAP_USER=<user> -> default: root"
  @echo "  DEPLOY_USER=<user>    -> default: nixos"
  @echo "  IDENTITY_FILE=<path>  -> optional SSH key for bootstrap/deploy"
  @echo "  SOPS_AGE_KEY_FILE=<path> -> optional age key file for deploy"
  @echo "  SOPS_AGE_KEY_PASS_ENTRY=<entry> -> default: sops/age-key"
  @echo "  DEPLOY_MODE=<auto|switch|boot> -> default: auto"
  @echo "  DEPLOY_REBOOT=<1|0> -> default: 1"
  @echo "  REMOTE_SSD_DEVICE=<device> -> default: /dev/sda"
  @echo "  ROOT_SIZE_GIB=<gib> -> default: 200"
  @echo "  BOOTSTRAP_POWEROFF=<1|0> -> default: 1"

image-build: ci
  @echo "Running CI checks before build..."
  @echo "Building builder container..."
  podman-compose build

build:
  . ./scripts/init.sh && export SSH_KEYS_PATH && podman-compose run --rm builder

disk-list:
  diskutil list

flash ssd_device=SSD_DEVICE:
  SSD_DEVICE={{ssd_device}} ./scripts/flash.sh

golden-create:
  GOLDEN_DEVICE={{GOLDEN_DEVICE}} GOLDEN_IMAGE={{GOLDEN_IMAGE}} ./scripts/golden-create.sh

golden-restore:
  GOLDEN_DEVICE={{GOLDEN_DEVICE}} GOLDEN_IMAGE={{GOLDEN_IMAGE}} ./scripts/golden-restore.sh

deploy:
  PI_HOST={{PI_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} SOPS_AGE_KEY_FILE={{SOPS_AGE_KEY_FILE}} SOPS_AGE_KEY_PASS_ENTRY={{SOPS_AGE_KEY_PASS_ENTRY}} DEPLOY_MODE={{DEPLOY_MODE}} DEPLOY_REBOOT={{DEPLOY_REBOOT}} ./scripts/deploy.sh

bootstrap:
  PI_HOST={{PI_HOST}} BOOTSTRAP_USER={{BOOTSTRAP_USER}} IDENTITY_FILE={{IDENTITY_FILE}} SSD_DEVICE={{REMOTE_SSD_DEVICE}} ROOT_SIZE_GIB={{ROOT_SIZE_GIB}} BOOTSTRAP_POWEROFF={{BOOTSTRAP_POWEROFF}} ./scripts/bootstrap.sh
  @echo "SSD prepared. Remove the SD card, boot from SSD, verify with 'just boot-source', then run 'just deploy'."
  @echo "If SSD boot stalls in initrd, keep ethernet connected and try SSHing to {{BOOTSTRAP_USER}}@{{PI_HOST}} with the same admin key."

boot-source:
  PI_HOST={{PI_HOST}} BOOT_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} ./scripts/boot-source.sh

validate:
  PI_HOST={{PI_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} ./scripts/validate.sh

restore:
  PI_HOST={{PI_HOST}} DEPLOY_USER={{DEPLOY_USER}} IDENTITY_FILE={{IDENTITY_FILE}} ./scripts/restore.sh

fmt:
  @echo "Formatting Nix files..."
  @nix fmt .
  @echo "Formatting complete"

fmt-check:
  @echo "Checking Nix file formatting..."
  @nix fmt -- --check .
  @echo "Format check passed"

check:
  @echo "Running checks..."
  @echo "  -> Flake check..."
  @nix flake check --no-build --all-systems 2>&1 || true
  @echo "  -> Statix lint..."
  @command -v statix >/dev/null 2>&1 && statix check . || echo "  - statix not installed, skipping"
  @echo "  -> Deadnix check..."
  @command -v deadnix >/dev/null 2>&1 && deadnix . || echo "  - deadnix not installed, skipping"
  @echo "Checks passed"

build-eval:
  @echo "Evaluating host configuration (forgejo-pi)..."
  @nix eval '.#nixosConfigurations.forgejo-pi.config.system.build.toplevel' --raw > /dev/null
  @echo "Evaluating image configuration (forgejo-pi-image)..."
  @nix eval '.#nixosConfigurations.forgejo-pi-image.config.system.build.sdImage' --raw > /dev/null
  @echo "Configurations are valid"

build-dry:
  @echo "Dry-run build (showing changes)..."
  @nix build .#nixosConfigurations.forgejo-pi.config.system.build.toplevel --no-link --dry-run
  @echo "Dry-run complete"

clean-cache:
  @echo "Cleaning Podman Nix cache volume..."
  @podman volume rm -f infrastructure-nixos_nix-store-cache >/dev/null 2>&1 || true
  @echo "Current Podman VM disk usage:"
  @podman machine ssh "df -h /var | tail -n +2"
  @echo "Cache cleanup complete"

ci: fmt-check check build-eval build-dry
  @echo "CI verification passed locally"
