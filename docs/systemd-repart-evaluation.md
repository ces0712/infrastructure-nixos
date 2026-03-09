# systemd-repart evaluation

## Current supported path

- Build one shared `sd-image`.
- Flash that same image to the SD card and SSD from the local workstation.
- Boot from SD.
- Run `just bootstrap` to resize the flashed SSD root partition and create the
  `NIXOS_DATA` partition.
- Remove the SD card and boot from SSD.
- Run `just deploy`.

This path is proven and remains the supported architecture.

## Evaluation scope

`systemd-repart` is only being considered for the non-boot SSD partitions.

Target scope:

- keep the flashed `sd-image` boot model
- keep the flashed SSD boot partition intact
- keep the flashed root partition as the initial runtime root
- evaluate whether `systemd-repart` can replace the extra-partition step now
  implemented by `scripts/bootstrap.sh`

Out of scope:

- replacing `sd-image`
- redesigning the image around GPT
- moving boot-partition ownership to `systemd-repart`
- changing the Raspberry Pi firmware boot path

## Why it is not the default today

The current stable system depends on the same `sd-image` machine model for:

- `forgejo-pi-image`
- `forgejo-pi`

That model is what made the Raspberry Pi boot path stable again. Introducing
`systemd-repart` directly into the mainline workflow before a separate
validation pass would add risk to the boot path that is already working.

## Acceptance criteria for adoption

`systemd-repart` is only worth adopting if all of these are true:

- no regression in Pi boot reliability
- no increase in recovery complexity
- fewer custom shell mutations than the current bootstrap step
- same resulting labels and runtime mounts from the runtime system's point of
  view
- still reproducible from scratch with local build and local flashing

## Migration rule

If a future `systemd-repart` experiment meets the acceptance criteria, replace
only the partition-creation part of `scripts/bootstrap.sh`.

If it does not clearly improve the process, keep `scripts/bootstrap.sh` as the
intentional supported disk-prep step.
