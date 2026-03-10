# From NixOS Theory to a Working Raspberry Pi 4 Forgejo Server

## Subtitle

How we stopped fighting the Raspberry Pi boot chain, kept the image model
simple, and ended up with a reproducible SD + SSD workflow for a NixOS Forgejo
server.

## Draft

I recently migrated a Raspberry Pi 4 Forgejo server to a cleaner NixOS workflow.
The goal sounded simple:

- build an image locally
- flash the Pi from my laptop
- boot a temporary installer environment
- move the real runtime onto an SSD
- keep everything reproducible

What actually happened was a long sequence of bootloader, initrd, partitioning,
and deployment failures that forced a more disciplined design.

This post explains the architecture that finally worked, why several
well-known NixOS tools were the wrong fit for this specific Raspberry Pi setup,
and what I would recommend if you want a reproducible Pi workflow without
constantly reflashing media.

## The Real Goal

The target machine is a Raspberry Pi 4 with:

- an SD card used only as a bootstrap medium
- a USB SSD used for the real runtime system
- Forgejo, Tailscale, SSH, backups, and secrets managed declaratively

The design constraints were:

1. I wanted to build the image on my computer.
2. I wanted local flashing to remain part of the supported workflow.
3. I did not want to hand-maintain a Raspberry Pi boot partition after install.
4. I wanted SSD runtime state separated from the flashed root image.
5. I wanted a recovery path that was understandable under pressure.

That last point matters more than people admit.

A design can look elegant on paper and still be a bad operational system if the
recovery story depends on remembering five different one-off commands when the
Pi is down.

## The First Wrong Ideas

### 1. `nixos-anywhere` as the mainline install path

On paper, this looked attractive:

- boot a temporary image
- run `nixos-anywhere`
- let it install the final system to SSD

In practice, it was the wrong abstraction for this machine.

The Pi boot chain was the real constraint. `nixos-anywhere` solved “remote
installation” but did not solve “Raspberry Pi 4 USB SSD boot reliability”.

The failures showed up as:

- `kexec` failures
- Bluetooth-related hangs during bootstrap
- target reconnect issues
- confusion around root vs `nixos` SSH paths
- re-entering the wrong environment after reboot

That stack added orchestration complexity without fixing the boot model.

### 2. `disko` owning the SSD layout

This was the second wrong direction.

`disko` is good when it owns the whole disk and your target machine model is
stable. In my case, the critical boot path was the flashed Raspberry Pi image
itself.

The important discovery was:

> The only consistently bootable system on this Pi was the `sd-image` model.

When `disko` became responsible for the SSD boot layout, I ended up fighting:

- missing Raspberry Pi firmware files
- mismatched boot partitions
- runtime generations that no longer booted
- bootloader state that diverged from the flashed image model

That was the wrong layer to optimize.

### 3. `systemd-repart` as a quick simplification

I evaluated `systemd-repart` because it is a good tool for image-based systems.

The problem was not the tool itself. The problem was the image format.

My stable Raspberry Pi image path was using the standard `sd-image` workflow,
which produced an MBR/DOS partition table. `systemd-repart` expects GPT.

So the “obvious” hybrid idea:

- keep the current image
- let `systemd-repart` create the extra SSD partitions

was blocked immediately by the underlying partition table.

That is an important lesson:

> A tool can be correct in general and still be the wrong tool for the exact
> machine model you have already proven in production.

## The Breakthrough

The architecture only became stable when I stopped trying to switch machine
models after bootstrap.

The working design is:

1. Build one shared NixOS Raspberry Pi `sd-image`.
2. Flash that same image to both the SD card and the SSD.
3. Boot the Pi from the SD card only.
4. Prepare the already-flashed SSD in place:
   - keep the boot partition
   - keep and resize the flashed root partition
   - create one extra data partition
5. Remove the SD card.
6. Boot from the SSD.
7. Deploy the full runtime configuration.

That sounds less “clever” than a full installer flow, but it is much more
robust.

## Why This Worked

Because it respected the only boot path that was consistently correct:

- Raspberry Pi firmware files on the flashed image
- U-Boot/extlinux state from the flashed image model
- the same `sd-image` machine model kept for the runtime too

The most important design decision was:

> The deployed SSD runtime keeps the same `sd-image` machine model as the
> flashed bootstrap image.

Once I accepted that, several weird failures stopped making sense as mysteries
and started making sense as architectural mismatch.

I had been trying to boot one machine model and then deploy into another.

That is what was causing:

- runtime generations that looked valid but did not boot
- confusion around where `/boot` and `/boot/firmware` really lived
- old generations booting when the new ones should have been default
- extra partition mounts interfering with system state

## The Final Disk Layout

The SSD now follows a simple rule:

- the flashed image owns the boot-critical pieces
- bootstrap only mutates the non-boot part of the disk

Result:

- `sda1` = `FIRMWARE`
- `sda2` = `NIXOS_SD`
- `sda3` = `NIXOS_DATA`

`NIXOS_DATA` is mounted at `/srv`, not `/var/lib`.

That change matters.

Mounting a whole extra partition on `/var/lib` created subtle failures because
it hid state that the booted system expected to find on the root filesystem.

Moving application state to `/srv` solved that cleanly:

- Forgejo state under `/srv/forgejo`
- backup state under `/srv/restic-backup`
- system-managed `/var/lib` stays on root

This is one of the main reasons the final runtime became stable.

## Making Bootstrap Reproducible Without Over-Engineering It

I still needed a bootstrap step, because SSD preparation is inherently a live
disk mutation task.

But I did not want a large, ad-hoc shell blob buried in the repo.

The compromise that worked was:

- Nix defines the partition policy and defaults
- shell only executes the partition plan remotely

Concretely:

- Nix generates `/etc/forgejo-pi-bootstrap.env`
- a dedicated executor script applies the plan on the Pi
- a thin local wrapper handles SSH orchestration

That gave me:

- reproducible partition intent
- no dependency on GPT
- no need to re-introduce `disko`
- far less “mystery shell” than the original bootstrap attempts

## Local-First Workflow

The final supported flow is intentionally small:

```bash
just image-build
just build
just flash device=/dev/diskSD
just flash device=/dev/diskSSD
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just bootstrap
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just boot-source
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just deploy
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just validate
```

The important thing here is not that every step is pretty. It is that every
step has a clear responsibility:

- `build` produces the shared image
- `flash` writes media locally
- `bootstrap` prepares the flashed SSD
- `boot-source` confirms the Pi is actually on SSD
- `deploy` switches to the runtime profile
- `validate` proves the runtime is healthy

That is a much better operational story than “run this installer, hope the
right reboot happens, and figure out later what environment you are actually
in”.

## Backup and Restore Were Part of the Design, Not an Afterthought

Getting the machine to boot was only half the problem.

The real test for a self-hosted service is whether you can recover it under
stress.

In the final design, backup and restore were validated as part of the
workflow, not documented as a future intention.

The runtime system now includes:

- Restic backups to Borgbase for Forgejo state and database snapshots
- Rclone backups to pCloud for Forgejo LFS objects
- declarative secret wiring through `sops`
- explicit validation commands for backup and restore readiness

The useful distinction is this:

- **backups** are not enough
- **tested restore procedures** are what turn backups into operational safety

That distinction drove the final workflow.

### What gets backed up

The server separates concerns deliberately:

- Forgejo application state lives under `/srv/forgejo`
- backup runtime state lives under `/srv/restic-backup`
- system state remains on the root filesystem

Restic covers:

- the SQLite database backup
- repositories
- Forgejo custom configuration and data

Rclone covers:

- the LFS object store

That split made the restore procedure simpler to reason about and easier to
validate independently.

### What gets tested

I added explicit operational checks for both backup and restore readiness:

```bash
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just backup-validate
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just restore-check
```

Those checks verify:

- timers are enabled and active
- secret files exist with the right ownership
- the Restic repository is reachable
- the pCloud target is reachable
- the expected runtime paths exist
- the restore prerequisites are valid before any destructive action happens

This turned backup verification into something operationally repeatable instead
of “I think the timer probably ran last night”.

### The restore workflow that actually worked

For this architecture, a realistic restore test on a new SSD is:

1. Flash the image.
2. Bootstrap the SSD.
3. Boot the SSD.
4. Deploy the runtime system.
5. Restore the Forgejo state.

That ordering matters.

The bootstrap image is not enough on its own because the restore procedure
expects the real runtime users, services, paths, and secret wiring to already
exist.

The tested restore path became:

```bash
just flash device=/dev/diskSSD
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just bootstrap
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just deploy
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just restore
PI_HOST=forgejo-pi IDENTITY_FILE=~/.ssh/id_ed25519 just validate
```

That restore flow was tested end to end on spare media.

The important result was not only that files restored. The important result was
that:

- the system booted
- the runtime profile converged
- Forgejo came back up
- repositories and backup paths were present again

That is the standard that actually matters for self-hosted infrastructure.

## Why This Work Matters Beyond One Raspberry Pi

The value in this kind of work is not the novelty of any one tool.

The value is in producing a recovery-oriented, reproducible operating model for
small infrastructure that would otherwise be maintained by trial and error.

The broader engineering contribution is this:

- identify where standard tools are the wrong fit for the real machine model
- reduce the supported workflow to something operators can actually execute
- validate recovery paths, not just happy-path deployment
- document the tradeoffs so other practitioners do not have to rediscover them

That is the part worth publishing.

It is practical, reusable, and directly relevant to real-world self-hosted
operations where reliability matters more than theoretical elegance.

## Lessons Learned

### 1. The Raspberry Pi boot chain deserves respect

The fastest way to lose time was pretending the Pi was just another generic
NixOS box.

It is not.

The boot partition, firmware files, and the image model all matter more here
than on a normal x86 VM or server.

### 2. Preserve the proven boot path

If you have one boot path that consistently works, keep it.

Do not replace it just because another tool looks cleaner on paper.

### 3. Separate boot-critical state from application data

Putting the extra data partition on `/srv` instead of `/var/lib` was one of the
highest-value fixes in the entire process.

### 4. Reproducibility is not the same as maximal abstraction

The final system is reproducible, but it is not built from the most abstract
possible toolchain.

That is fine.

The goal was not to use the most Nix-native partitioning tool available. The
goal was a system that I could rebuild from scratch and recover reliably.

### 5. A thin script is acceptable when the action is inherently imperative

Disk mutation on a live target is one of those cases.

Trying to eliminate all shell just to feel more declarative usually creates a
worse design, not a better one.

## Would I Use `systemd-repart` in the Future?

Maybe, but only after a deliberate image redesign.

Not as an incremental tweak on top of the current workflow.

If I revisit it, I would do it as:

- a GPT-first image experiment
- on separate media
- with no changes to the stable mainline until the prototype proves equal or
  better boot reliability

Until then, the current design is the right tradeoff.

## Final Architecture

The end result is simple:

- keep local flashing
- keep a shared flashed `sd-image`
- preserve the Raspberry Pi boot path
- bootstrap only the non-boot SSD layout
- deploy the runtime on the same image model
- keep runtime data on `/srv`

That is not the most theoretically elegant solution.

It is the one that actually survived repeated full-cycle testing.

And for infrastructure, that matters more.

## Suggested Tags

- `nixos`
- `raspberrypi`
- `devops`
- `selfhosted`
- `forgejo`
