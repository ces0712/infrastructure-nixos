# NixOS Infrastructure for Raspberry Pi 4

NixOS configuration for a Raspberry Pi 4 hosting [Forgejo](https://forgejo.org/)
(self-hosted Git service).

## Hardware

- Raspberry Pi 4 (8GB)
- USB SSD (512GB) for storage

## Quick Start

### Prerequisites

- [Podman](https://podman.io/) with `podman-compose`
- [just](https://github.com/casey/just)
- SSH access to the Pi

### Recommended Workflow (Flash Both, Then Prepare SSD From SD)

```bash
# 1. Build the builder container when setting up from scratch or after
#    changing container/build dependencies
just image-build

# 2. Build the shared bootstrap image
just build

# 3. Flash the same image to the SD card and the SSD from your computer
just flash device=/dev/diskSD
just flash device=/dev/diskSSD

# 4. Boot the Pi from the SD card only
# 5. After the SD system is up, connect the flashed SSD
# 6. Prepare the SSD in place: keep partitions 1-2 from the flashed image,
#    apply the declarative SSD layout plan, and power off
PI_HOST=forgejo-pi.tail8f7f61.ts.net just bootstrap

# 7. Remove the SD card and boot from the SSD
PI_HOST=forgejo-pi.tail8f7f61.ts.net just boot-source

# 8. Switch the SSD system to the full Forgejo runtime profile
PI_HOST=forgejo-pi.tail8f7f61.ts.net just deploy

# 9. Validate that the SSD runtime is stable
PI_HOST=forgejo-pi.tail8f7f61.ts.net just validate

# 10. Validate backup and restore readiness (optional)
PI_HOST=forgejo-pi.tail8f7f61.ts.net just backup-validate
PI_HOST=forgejo-pi.tail8f7f61.ts.net just restore-check

# 11. Restore data from backups (optional, destructive)
PI_HOST=forgejo-pi.tail8f7f61.ts.net just restore
```

This is the only supported install path. The SSD keeps the flashed, known-good
Pi boot partition from the image. Bootstrap no longer rebuilds the SSD boot
partition and no longer uses `nixos-anywhere`.

Important: the deployed SSD target keeps the same `sd-image` machine model as
the flashed bootstrap image.

The shared image reserves a `512MiB` `FIRMWARE` partition for Raspberry Pi
firmware files. On this `sd-image` layout, runtime boot entries live on the
root filesystem under `/boot`, while the FAT partition is mounted separately at
`/boot/firmware`.

This workflow intentionally does not use `systemd-repart`. The current,
proven Raspberry Pi boot path is the shared flashed `sd-image` layout, and that
image keeps the boot-critical partitioning model expected by this setup.

If your admin SSH key is not the default key, pass it explicitly:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net IDENTITY_FILE=~/.ssh/id_ed25519 just bootstrap
```

`just deploy` pushes the stable SOPS age key to
`/var/lib/sops-nix/key.txt` before switching the runtime system. By default it
reads that key from `pass show sops/age-key`. Override that when needed:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
IDENTITY_FILE=~/.ssh/id_ed25519 \
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
just deploy
```

`just deploy` always stages the new generation with `nixos-rebuild boot`, then
reboots by default. After reboot, reconnect manually to verify the new
generation.

To stage the deployment without rebooting immediately, use:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
IDENTITY_FILE=~/.ssh/id_ed25519 \
DEPLOY_REBOOT=0 \
just deploy
```

Then verify `/boot/extlinux/extlinux.conf` on the Pi before rebooting manually.

`just bootstrap` assumes the remote SSD is `/dev/sda` and applies the
declarative SSD layout defaults from Nix:

- keep `FIRMWARE` as partition 1
- keep and grow `NIXOS_SD` as partition 2
- create `NIXOS_DATA` as partition 3
- default root target size: `200GiB`

Override the remote disk or root target size if needed:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
REMOTE_SSD_DEVICE=/dev/sdb \
ROOT_SIZE_GIB=160 \
just bootstrap
```

### Local build and flash commands

```bash
# 0. Start podman root mode
podman machine stop
podman machine set --rootful=true  # or false
podman machine start

# 1. Build or refresh the builder container (runs CI checks first)
just image-build

# 2. Build the shared bootstrap image
just build

# 3. List available disks
just disk-list

# 4. Flash the image to both the SD card and the SSD
just flash device=/dev/diskSD
just flash device=/dev/diskSSD
```

`just flash` is intentionally a thin local wrapper around `diskutil` and `dd`.
It does not change the supported architecture; it only automates the host-side
media write step.

The optional golden image helpers use the same argument style:

```bash
just golden-create device=/dev/diskSSD image=output/golden.img.zst
just golden-restore device=/dev/diskSSD image=output/golden.img.zst
```

`just image-build` is only needed when setting up from scratch or after
changing the builder container inputs. The normal day-to-day loop is usually
`just build`.

The SSD runtime layout expects these labels:
- `FIRMWARE` on partition 1 from the flashed image
- `NIXOS_SD` on partition 2 from the flashed image
- `NIXOS_DATA` on the extra data partition created by `just bootstrap`, mounted at `/srv`

### Just Targets

| Target | Description |
|--------|-------------|
| `bootstrap` | From the SD-booted image, resize the flashed SSD root and create the `NIXOS_DATA` partition |
| `image-build` | Build the Podman builder container (runs CI checks first) |
| `build` | Build NixOS Raspberry Pi image (`forgejo-pi-image`) |
| `disk-list` | List available disks on macOS |
| `flash` | Thin local wrapper around `diskutil` + `dd` |
| `boot-source` | Show whether the Pi is currently running from SD or SSD |
| `validate` | Verify the SSD runtime profile, mounts, and core services |
| `backup-validate` | Verify backup timers, secrets, and access to Borgbase/pCloud |
| `restore-check` | Verify restore prerequisites without changing live data |
| `deploy` | Deploy the Forgejo runtime configuration |
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
- `disk.nix` - Runtime filesystem mounts for the flashed SSD layout

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
- **Golden SSD image (optional recovery)**: Offline compressed image captured
  from a known-good SSD

## Backup / Restore Validation

Use these commands before relying on backup or restore in production:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net just backup-validate
PI_HOST=forgejo-pi.tail8f7f61.ts.net just restore-check
```

Run the real restore only after both checks pass:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net just restore
```

## Troubleshooting

### SSD preparation flow

The supported flow is:

1. flash the shared image to both SD and SSD
2. boot from SD only
3. hot-plug or connect the flashed SSD
4. run `just bootstrap` to resize the SSD root and create `NIXOS_DATA`
5. remove SD and boot the SSD
6. run `just deploy`

The full runtime now mounts `NIXOS_DATA` at `/srv` instead of replacing
`/var/lib`. Forgejo state lives under `/srv/forgejo` and backup state under
`/srv/restic-backup`, while system `/var/lib` stays on the root filesystem.
Backup secrets themselves stay under `/run/secrets`, not on `/srv`.

### First boot SSH access

The shared image injects your admin SSH key for `root`
(`hosts/forgejo-pi/bootstrap-ssh.nix`) so you can prepare the SSD and recover
the machine without passwords. Use:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net IDENTITY_FILE=~/.ssh/id_ed25519 just bootstrap
```

If the SSD boot reaches the initrd emergency path and local keyboard input does
not work, keep ethernet connected and try SSHing into the initrd instead:

```bash
ssh -i ~/.ssh/id_ed25519 \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  root@forgejo-pi.tail8f7f61.ts.net
```

The bootstrap profile now enables wired DHCP plus initrd SSH specifically so
stage-1 can be debugged remotely without relying on HDMI console input.

### Verify you are on the SSD system

After removing the SD card and booting again:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net just boot-source
```

Expected result:

- `root-source` should point to `/dev/sda2` or another SSD-backed mapper path.
- `root-disk` should be `sda`.

If `root-source` is still on `mmcblk*`, you are still running from the SD
bootstrap image and should not run `just bootstrap` again. Power off, remove
the SD card, and boot from SSD only.

### SOPS age key during deploy

The runtime system expects a stable key at:

```bash
/var/lib/sops-nix/key.txt
```

`just deploy` provisions that file before `nixos-rebuild switch`. Lookup order:

1. `SOPS_AGE_KEY_FILE`
2. `SOPS_AGE_KEY`
3. `pass show sops/age-key`

If none of those resolve, deploy stops before activation.

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
# Preferred operational path
PI_HOST=forgejo-pi.tail8f7f61.ts.net IDENTITY_FILE=~/.ssh/id_ed25519 just deploy

# Direct rebuild (same default SSH user model)
nixos-rebuild switch --flake .#forgejo-pi --target-host nixos@forgejo-pi.tail8f7f61.ts.net --use-remote-sudo
```

### Rollback

```bash
# List generations
sudo nix-env --list-generations -p /nix/var/nix/profiles/system

# Rollback to previous generation
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch --rollback
```
