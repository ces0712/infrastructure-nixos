#!/bin/sh

die() {
  echo "$*" >&2
  exit 1
}

target_host() {
  user="$1"
  host="$2"
  printf '%s@%s' "${user}" "${host}"
}

standard_ssh_opts() {
  identity_file="${1:-}"
  opts="-o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=yes -o ConnectTimeout=10"
  if [ -n "${identity_file}" ]; then
    opts="${opts} -o IdentityFile=${identity_file} -o IdentitiesOnly=yes"
  fi
  printf '%s' "${opts}"
}

require_block_device() {
  device="$1"
  if [ ! -b "${device}" ]; then
    echo "Error: device not found: ${device}" >&2
    exit 1
  fi
}

disk_identifier() {
  device="$1"
  printf '%s' "${device#/dev/}"
}

require_unmounted_disk() {
  device="$1"
  disk_id="$(disk_identifier "${device}")"

  if mount | grep -q "^/dev/${disk_id}"; then
    echo "Error: ${device} has mounted partitions." >&2
    echo "Run: diskutil unmountDisk ${device}" >&2
    exit 1
  fi
}

confirm_continue() {
  prompt="${1:-Press ENTER to continue or Ctrl+C to abort}"
  echo "${prompt}"
  read -r
}

ssh_target() {
  user="$1"
  host="$2"
  identity_file="${3:-}"
  printf '%s\n' "$(standard_ssh_opts "${identity_file}")|$(target_host "${user}" "${host}")"
}

remote_run() {
  ssh_opts="$1"
  target="$2"
  shift 2
  ssh ${ssh_opts} "${target}" "$@"
}

remote_wait_for_ssh() {
  ssh_opts="$1"
  target="$2"

  until remote_run "${ssh_opts}" "${target}" true 2>/dev/null; do
    echo "Retrying..."
    sleep 5
  done
}
