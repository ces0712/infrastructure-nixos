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

### Recommended Workflow (Flash Both, Then Prepare SSD From SD)

```bash
# 1. Build the shared bootstrap image once
just build

# 2. Flash the same image to the SD card and the SSD from your computer
just flash ssd_device=/dev/diskSD
just flash ssd_device=/dev/diskSSD

# 3. Boot the Pi from the SD card only
# 4. After the SD system is up, connect the flashed SSD
# 5. Prepare the SSD in place: keep partitions 1-2 from the flashed image,
#    enlarge root, create the data partition, then power off
PI_HOST=forgejo-pi.tail8f7f61.ts.net just bootstrap

# 6. Remove the SD card and boot from the SSD
PI_HOST=forgejo-pi.tail8f7f61.ts.net just boot-source

# 7. Switch the SSD system to the full Forgejo runtime profile
PI_HOST=forgejo-pi.tail8f7f61.ts.net just deploy

# 8. Validate that the SSD runtime is stable
PI_HOST=forgejo-pi.tail8f7f61.ts.net just validate

# 9. Restore data from backups (optional)
PI_HOST=forgejo-pi.tail8f7f61.ts.net just restore
```

This is the only supported install path. The SSD keeps the flashed, known-good
Pi boot partition from the image. Bootstrap no longer rebuilds the SSD boot
partition and no longer uses `nixos-anywhere`.

Important: the deployed SSD targets keep the same `sd-image` machine model as
the flashed bootstrap image. Only the service layer changes between:

- `forgejo-pi-core` - boot-safe intermediate runtime
- `forgejo-pi` - full Forgejo runtime

The shared image reserves a `512MiB` `FIRMWARE` partition for Raspberry Pi
firmware files. On this `sd-image` layout, runtime boot entries live on the
root filesystem under `/boot`, while the FAT partition is mounted separately at
`/boot/firmware`.

This workflow intentionally does not use `systemd-repart`. The current,
proven Raspberry Pi boot path is the shared flashed `sd-image` layout, and that
image keeps the boot-critical partitioning model expected by this setup.
`systemd-repart` would only be a good fit after an intentional redesign to a
GPT-first image model.

The current design evaluation for `systemd-repart` is documented in
[`docs/systemd-repart-evaluation.md`](./docs/systemd-repart-evaluation.md).

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

`just deploy` defaults to `DEPLOY_MODE=auto`: it tries a live `switch` first,
and if the Pi drops off the system bus during activation it falls back to
`boot` plus a reboot into the new generation.

After reboot, deploy prints a reconnect message and exits. Reconnect manually to
verify the new generation.

If the full runtime still trips early boot, deploy the boot-safe intermediate
profile first:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
IDENTITY_FILE=~/.ssh/id_ed25519 \
DEPLOY_MODE=boot \
DEPLOY_REBOOT=0 \
just deploy-core
```

`forgejo-pi-core` keeps the same `sd-image` base and SSD/runtime layout, but
does not yet layer Forgejo, Tailscale, backups, or SOPS-managed runtime
services.

To stage a `boot` deployment without rebooting immediately, use:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
IDENTITY_FILE=~/.ssh/id_ed25519 \
DEPLOY_MODE=boot \
DEPLOY_REBOOT=0 \
just deploy
```

Then verify `/boot/extlinux/extlinux.conf` on the Pi before rebooting manually.

`just bootstrap` assumes the remote SSD is `/dev/sda` and expands the flashed
root partition to `200GiB` before creating the `NIXOS_DATA` partition. Override
those defaults if needed:

```bash
PI_HOST=forgejo-pi.tail8f7f61.ts.net \
REMOTE_SSD_DEVICE=/dev/sdb \
ROOT_SIZE_GIB=160 \
just bootstrap
```

### Local flash commands

```bash
# 0. Start podman root mode
podman machine stop
podman machine set --rootful=true  # or false
podman machine start

# 1. Build the builder container (runs CI checks first)
just image-build

# 2. Build the shared bootstrap image
just build

# 3. List available disks
just disk-list

# 4. Flash the image to both the SD card and the SSD
just flash ssd_device=/dev/diskSD
just flash ssd_device=/dev/diskSSD
```

`just flash` is intentionally a thin local wrapper around `diskutil` and `dd`.
It does not change the supported architecture; it only automates the host-side
media write step.

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
| `deploy` | Deploy runtime configuration (`forgejo-pi` by default) |
| `deploy-core` | Deploy the boot-safe intermediate runtime profile (`forgejo-pi-core`) |
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
- **Golden SSD image (optional)**: Offline compressed image captured from a
  known-good SSD

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
