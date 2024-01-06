#!/bin/bash
set -euo pipefail

if [[ -n ${VERBOSE:-} ]]; then
  set -x
fi

# run max age if requested
MAX_AGE="${MAX_AGE:-}"
TARGET_DIR="${TARGET_DIR:-}"
SOURCE_DIR="${SOURCE_DIR:-}"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "Unknown TARGET_DIR"
  exit 1
fi
if [[ -z "${SOURCE_DIR}" ]]; then
  echo "Unknown SOURCE_DIR"
  exit 1
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Destination directory not found"
  exit 1
fi

if [[ "${SOURCE_DIR}" == /* ]] && [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Source directory not found"
  exit 1
fi

TIMESTAMP="$(date +%H.%M_%d-%m-%Y)"
TARGET_DIR_PATH="${TARGET_DIR/%\//}/daily"
COMPLETE_TARGET_DIR="${TARGET_DIR_PATH}.backup_${TIMESTAMP}"
INCOMPLETE_TARGET_DIR="${TARGET_DIR_PATH}.incomplete"
CURRENT_TARGET_DIR="${TARGET_DIR_PATH}.current"

# this is not targeted as a reusable container
SSH_KEYFILE=""
SSH_KEYFILE_TMP=
# shellcheck disable=SC2174
mkdir -p --mode=0700 /tmp/ssh-temp
if [[ -r /mnt/id_rsa ]] && [[ -r /mnt/id_rsa.pub ]]; then
  SSH_KEYFILE_TMP="$(mktemp /tmp/ssh-temp/ssh.id_rsa.XXXXXX)"
  cat /mnt/id_rsa >"${SSH_KEYFILE_TMP}"
  cat /mnt/id_rsa.pub >"${SSH_KEYFILE_TMP}.pub"
  chmod 600 "${SSH_KEYFILE_TMP}" "${SSH_KEYFILE_TMP}.pub"
  SSH_KEYFILE="-i ${SSH_KEYFILE_TMP}"
fi
if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
  SSH_KEYFILE_TMP="$(mktemp /tmp/ssh-temp/ssh.id_rsa.XXXXXX)"
  set +x
  echo "${SSH_PRIVATE_KEY}" >"${SSH_KEYFILE_TMP}"
  if [[ -n ${VERBOSE:-} ]]; then
    set -x
  fi
  chmod 600 "${SSH_KEYFILE_TMP}"
  SSH_KEYFILE="-i ${SSH_KEYFILE_TMP}"

  if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    set +x
    echo "${SSH_PUBLIC_KEY}" >"${SSH_KEYFILE_TMP}.pub"
    if [[ -n ${VERBOSE:-} ]]; then
      set -x
    fi
    chmod 600 "${SSH_KEYFILE_TMP}.pub"
  fi
fi

# ssh verbosity level
SSH_LOGGING_LEVEL="-q"
if [[ -n ${VERBOSE:-} ]]; then
  SSH_LOGGING_LEVEL="-v"
fi

# setup initial structure
if [[ ! -L "${CURRENT_TARGET_DIR}" ]]; then
  mkdir "${CURRENT_TARGET_DIR}.tmp"
  (cd "${TARGET_DIR}" && ln -s "$(basename "${CURRENT_TARGET_DIR}").tmp" "${CURRENT_TARGET_DIR}")
fi

# Clean up stray files
function cleanup() {
  if [[ -e "${SSH_KEYFILE_TMP}" ]]; then
    rm -f "${SSH_KEYFILE_TMP}" "${SSH_KEYFILE_TMP}.pub"
  fi
  if [[ -d "${CURRENT_TARGET_DIR}.tmp" ]]; then
    rm -rf "${CURRENT_TARGET_DIR}.tmp"
  fi
}
trap cleanup EXIT

# shellcheck disable=SC2191,SC2206
RSYNC_ARGS=(
  -avh
  --archive
  --one-file-system
  --hard-links
  --human-readable
  --inplace
  --numeric-ids
  --delete
  --ignore-errors
  --verbose
  -F # --filter='dir-merge /.rsync-filter' repeated: --filter='- .rsync-filter'
  --rsh="ssh -p ${SSH_PORT:-22} ${SSH_LOGGING_LEVEL} -o ConnectTimeout=${SSH_CONNECT_TIMEOUT:-5} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SSH_KEYFILE} ${SSH_OPTIONS:-}"
  --link-dest="${CURRENT_TARGET_DIR}/"
  ${RSYNC_OPTIONS:-}
  "${SOURCE_DIR/%\//}/"
  "${INCOMPLETE_TARGET_DIR}/"
)

# 1. Copy over all files
# 2. only when successful, move he incomplete path to a completed path
# 3. delete the quick reference symlink the most recent backup
# 4. make a new reference to the latest backup
# 5. make sure this folder's last modified time is now!
rsync "${RSYNC_ARGS[@]}" \
  && mv "${INCOMPLETE_TARGET_DIR}" "${COMPLETE_TARGET_DIR}" \
  && rm -f "${CURRENT_TARGET_DIR}" \
  && (cd "${TARGET_DIR}" && ln -s "$(basename "${COMPLETE_TARGET_DIR}")" "${CURRENT_TARGET_DIR}") \
  && touch "${COMPLETE_TARGET_DIR}"

# only run the dedupe on success
RSYNC_EXIT_CODE=$?

# run deduplication if requested
if [[ ${RSYNC_EXIT_CODE} -eq 0 ]] && [[ -n ${DEDUPLICATE:-} ]]; then
  disk-dedupe.sh "${TARGET_DIR/%\//}" "${COMPLETE_TARGET_DIR}"
fi

# run max age if requested
if [[ ${RSYNC_EXIT_CODE} -eq 0 ]] && [[ ${MAX_AGE} ]]; then
  echo "Backup completed. Starting retention clean up of $MAX_AGE days."
  disk-cleanup.sh
fi
