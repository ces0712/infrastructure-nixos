#!/bin/sh
set -eu

config_file="${BOOTSTRAP_CONFIG_FILE:-/etc/forgejo-pi-bootstrap.env}"
if [ -f "${config_file}" ]; then
  # shellcheck disable=SC1090
  . "${config_file}"
fi

disk="${SSD_DEVICE:-${BOOTSTRAP_SSD_DEVICE:-/dev/sda}}"
root_size_gib="${ROOT_SIZE_GIB:-${BOOTSTRAP_ROOT_SIZE_GIB:?BOOTSTRAP_ROOT_SIZE_GIB is required}}"
poweroff_after="${BOOTSTRAP_POWEROFF:-${BOOTSTRAP_POWEROFF_DEFAULT:-1}}"

boot_label="${BOOTSTRAP_BOOT_LABEL:?BOOTSTRAP_BOOT_LABEL is required}"
root_label="${BOOTSTRAP_ROOT_LABEL:?BOOTSTRAP_ROOT_LABEL is required}"
data_label="${BOOTSTRAP_DATA_LABEL:?BOOTSTRAP_DATA_LABEL is required}"
data_fs="${BOOTSTRAP_DATA_FS:?BOOTSTRAP_DATA_FS is required}"

boot_part="${disk}1"
root_part="${disk}2"
data_part="${disk}3"

current_root="$(findmnt -n -o SOURCE / || true)"
case "${current_root}" in
  "${disk}"*|/dev/disk/by-*${disk##*/}*)
    echo "Refusing to modify ${disk}: it appears to host the live root filesystem."
    exit 1
    ;;
esac

for part in "${boot_part}" "${root_part}" "${data_part}"; do
  if findmnt -rn "${part}" >/dev/null 2>&1; then
    echo "Unmounting ${part} ..."
    umount "${part}"
  fi
done

if [ ! -b "${boot_part}" ] || [ ! -b "${root_part}" ]; then
  echo "Expected flashed SSD partitions ${boot_part} and ${root_part} were not found."
  exit 1
fi

dump="$(sfdisk -d "${disk}")"
label_id="$(printf '%s\n' "${dump}" | awk '/^label-id:/ { print $2; exit }')"

boot_line="$(printf '%s\n' "${dump}" | awk -v dev="${boot_part}" '$1 == dev { print; exit }')"
root_line="$(printf '%s\n' "${dump}" | awk -v dev="${root_part}" '$1 == dev { print; exit }')"

if [ -z "${boot_line}" ] || [ -z "${root_line}" ]; then
  echo "Could not read existing partition table for ${disk}."
  exit 1
fi

boot_start="$(printf '%s\n' "${boot_line}" | awk 'match($0, /start=[[:space:]]*([0-9]+)/, m) { print m[1]; exit }')"
boot_size="$(printf '%s\n' "${boot_line}" | awk 'match($0, /size=[[:space:]]*([0-9]+)/, m) { print m[1]; exit }')"
boot_type="$(printf '%s\n' "${boot_line}" | awk 'match($0, /type=([A-Za-z0-9]+)/, m) { print m[1]; exit }')"
bootable=""
if printf '%s\n' "${root_line}" | grep -q 'bootable'; then
  bootable=", bootable"
fi

root_start="$(printf '%s\n' "${root_line}" | awk 'match($0, /start=[[:space:]]*([0-9]+)/, m) { print m[1]; exit }')"
root_type="$(printf '%s\n' "${root_line}" | awk 'match($0, /type=([A-Za-z0-9]+)/, m) { print m[1]; exit }')"

sector_size="$(blockdev --getss "${disk}")"
total_sectors="$(blockdev --getsz "${disk}")"
root_size_sectors="$((root_size_gib * 1024 * 1024 * 1024 / sector_size))"
data_start="$((root_start + root_size_sectors))"

if [ "${data_start}" -ge "${total_sectors}" ]; then
  echo "Requested root size leaves no room for a data partition on ${disk}."
  exit 1
fi

plan="$(mktemp)"
trap 'rm -f "${plan}"' EXIT

{
  echo "label: dos"
  if [ -n "${label_id}" ]; then
    echo "label-id: ${label_id}"
  fi
  echo "device: ${disk}"
  echo "unit: sectors"
  echo
  echo "${boot_part} : start= ${boot_start}, size= ${boot_size}, type=${boot_type}"
  echo "${root_part} : start= ${root_start}, size= ${root_size_sectors}, type=${root_type}${bootable}"
  echo "${data_part} : start= ${data_start}, type=83"
} > "${plan}"

echo "Current SSD layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "${disk}"

echo "Applying declarative sfdisk plan to ${disk} ..."
cat "${plan}"
sfdisk --no-reread --force "${disk}" < "${plan}"
partprobe "${disk}" || true
udevadm settle || true

echo "Checking and growing ${root_part} ..."
e2fsck -fy "${root_part}" || rc=$?
if [ "${rc:-0}" -gt 1 ]; then
  exit "${rc}"
fi
unset rc
resize2fs "${root_part}"
e2label "${root_part}" "${root_label}"

echo "Creating ${data_fs} filesystem on ${data_part} ..."
wipefs -a "${data_part}" >/dev/null 2>&1 || true
case "${data_fs}" in
  ext4)
    mkfs.ext4 -F -L "${data_label}" "${data_part}"
    ;;
  *)
    echo "Unsupported data filesystem: ${data_fs}"
    exit 1
    ;;
esac

fatlabel "${boot_part}" "${boot_label}" || true

echo "Resulting SSD layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "${disk}"

if [ "${poweroff_after}" = "1" ]; then
  echo "SSD bootstrap complete. Powering off so you can remove the SD card..."
  exec systemctl poweroff
fi
