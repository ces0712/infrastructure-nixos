#!/bin/sh
set -eu

. "$(dirname "$0")/libssh.sh"

PI_HOST="${PI_HOST:?PI_HOST is required}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-root}"
IDENTITY_FILE="${IDENTITY_FILE:-}"
SSD_DEVICE="${SSD_DEVICE:-/dev/sda}"
ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-200}"
BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF:-1}"

TARGET="$(target_host "${BOOTSTRAP_USER}" "${PI_HOST}")"

echo "Preparing flashed SSD ${SSD_DEVICE} on ${TARGET}..."
echo "Bootstrap expects:"
echo "  ${SSD_DEVICE}1 -> flashed FIRMWARE"
echo "  ${SSD_DEVICE}2 -> flashed NIXOS_SD"
echo "Bootstrap will keep 1-2, grow 2, and recreate:"
echo "  ${SSD_DEVICE}3 -> NIXOS_DATA"

ssh_opts="$(standard_ssh_opts "${IDENTITY_FILE}")"

ssh ${ssh_opts} "${TARGET}" \
  SSD_DEVICE="${SSD_DEVICE}" ROOT_SIZE_GIB="${ROOT_SIZE_GIB}" BOOTSTRAP_POWEROFF="${BOOTSTRAP_POWEROFF}" \
  'sh -s' <<'EOF'
set -eu

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

disk="${SSD_DEVICE}"
root_size_gib="${ROOT_SIZE_GIB}"
boot_part="${disk}1"
root_part="${disk}2"
data_part="${disk}3"

current_root="$(findmnt -n -o SOURCE / || true)"
case "${current_root}" in
  "${disk}"*|/dev/disk/by-*"${disk##*/}"*)
    echo "Refusing to modify ${disk}: it appears to host the live root filesystem."
    exit 1
    ;;
esac

for part in "${boot_part}" "${root_part}" "${data_part}"; do
  if findmnt -rn "${part}" >/dev/null 2>&1; then
    echo "Unmounting ${part} ..."
    ${SUDO} umount "${part}"
  fi
done

if [ ! -b "${boot_part}" ] || [ ! -b "${root_part}" ]; then
  echo "Expected flashed SSD partitions ${boot_part} and ${root_part} were not found."
  exit 1
fi

echo "Current SSD layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "${disk}"

${SUDO} parted -s "${disk}" rm 4 >/dev/null 2>&1 || true
${SUDO} parted -s "${disk}" rm 3 >/dev/null 2>&1 || true

echo "Resizing ${root_part} to ${root_size_gib}GiB..."
${SUDO} parted -s "${disk}" resizepart 2 "${root_size_gib}GiB"
${SUDO} partprobe "${disk}" || true
udevadm settle || true

echo "Checking and growing ${root_part}..."
${SUDO} e2fsck -fy "${root_part}" || rc=$?
if [ "${rc:-0}" -gt 1 ]; then
  exit "${rc}"
fi
unset rc
${SUDO} resize2fs "${root_part}"
${SUDO} e2label "${root_part}" NIXOS_SD

echo "Creating data partition on remaining SSD space..."
${SUDO} parted -s -a optimal "${disk}" mkpart primary ext4 "${root_size_gib}GiB" 100%
${SUDO} partprobe "${disk}" || true
udevadm settle || true

${SUDO} mkfs.ext4 -F -L NIXOS_DATA "${data_part}"
${SUDO} fatlabel "${boot_part}" FIRMWARE || true

echo "Resulting SSD layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "${disk}"

if [ "${BOOTSTRAP_POWEROFF}" = "1" ]; then
  echo "SSD bootstrap complete. Powering off so you can remove the SD card..."
  exec ${SUDO} systemctl poweroff
fi
EOF
