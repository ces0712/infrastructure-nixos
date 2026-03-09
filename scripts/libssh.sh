#!/bin/sh

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
