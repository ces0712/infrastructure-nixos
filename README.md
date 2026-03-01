# NixOS Infrastructure for Raspberry Pi 4

NixOS configuration for a Raspberry Pi 4 hosting [Forgejo](https://forgejo.org/)
(self-hosted Git service).

## Hardware

- Raspberry Pi 4 (8GB)
- USB SSD (512GB) for storage

## Quick Start

### Prerequisites

- [Podman](https://podman.io/) or Docker
- [just](https://github.com/casey/just)
- SSH access to the Pi

### Build & Deploy (Phase 1: Bootable image)

```bash
# 0. Start podman root mode 
podman machine stop
podman machine set --rootful=true  # or false
podman machine start

# 1. Build the builder container (runs CI checks first)
just image-build

# 2. Build NixOS image
just build

# 3. List available disks
just disk-list

# 4. Flash image to SSD/SD card (WARNING: destroys data on target device)
just flash ssd_device=/dev/diskX

# 5. Plug SSD into Pi and boot

# 6. Deploy configuration
just deploy pi_host=forgejo-pi.tail8f7f61.ts.net

# 7. Restore data from backups (optional)
just restore pi_host=forgejo-pi.tail8f7f61.ts.net
```

### Optional Phase 2: Apply custom SSD partitions (Disko profile)

After first successful boot/deploy, switch to the disko profile:

```bash
just deploy-disko pi_host=forgejo-pi.tail8f7f61.ts.net
```

This profile expects these labels from `hosts/forgejo-pi/disk.nix`:
- `disk-ssd-boot`
- `disk-ssd-root`
- `disk-ssd-nix`
- `disk-ssd-data`
- `disk-ssd-swap`

### Just Targets

| Target | Description |
|--------|-------------|
| `image-build` | Build the Podman builder container (runs CI checks first) |
| `build` | Build NixOS Raspberry Pi image (`forgejo-pi-image`) |
| `disk-list` | List available disks on macOS |
| `flash` | Flash image to SSD/SD card |
| `deploy` | Deploy runtime configuration (`forgejo-pi`) |
| `deploy-disko` | Deploy disko partition profile (`forgejo-pi-disko`) |
| `restore` | Restore Forgejo data from backups |
| `fmt` | Format Nix files |
| `fmt-check` | Check formatting without changes |
| `check` | Run linting and validation |
| `build-eval` | Evaluate runtime and image configs |
| `build-dry` | Dry-run build showing changes |
| `ci` | Run all CI checks locally |

## Configuration

### NixOS Host

Edit files in `hosts/forgejo-pi/`:

- `default.nix` - Core system config
- `forgejo.nix` - Forgejo service settings
- `backup.nix` - Backup configuration (Restic → Borgbase, Rclone → pCloud)
- `networking.nix` - Tailscale, SSH, fail2ban
- `hardware.nix` - Kernel, Raspberry Pi specific settings
- `disk.nix` - Disko partition layout

### Secrets

Managed via [sops-nix](https://github.com/Mic92/sops-nix). Secrets stored in
separate repository: `infrastructure-secrets`

## Services

| Service | Port | Description |
|---------|------|-------------|
| Forgejo | 3000 | Git repository hosting |
| Forgejo SSH | 2222 | Git SSH access |
| Tailscale | 41641 | VPN networking |

## Backup Strategy

- **Restic → Borgbase**: Daily append-only backups (repositories, custom files,
database)
- **Rclone → pCloud**: Weekly LFS object backups

## Troubleshooting

### Black screen / stage-1 boot failure after flashing

If HDMI stays black and stage-1 fails to mount root, ensure you built the
dedicated image profile:

```bash
just build
```

`just build` now uses `forgejo-pi-image`, which avoids forcing disko partition
labels during image boot.

### View logs

```bash
# SSH into Pi
ssh nixos@forgejo-pi.tail8f7f61.ts.net

# View Forgejo logs
sudo journalctl -u forgejo -f

# View all NixOS logs
sudo journalctl -b -f
```

### Rebuild

```bash
# Rebuild and switch
nixos-rebuild switch --flake .#forgejo-pi --target-host root@forgejo-pi.tail8f7f61.ts.net
```

### Rollback

```bash
# List generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system

# Rollback to previous generation
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch --rollback
```
