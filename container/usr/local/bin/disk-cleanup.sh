#!/bin/bash
set -euo pipefail

if [[ -n ${VERBOSE:-} ]]; then
  set -x
fi

TARGET_DIR="${TARGET_DIR:-}"
MAX_AGE="${MAX_AGE:-180}"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "Unknown TARGET_DIR"
  exit 1
fi

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Destination directory not found"
  exit 1
fi

TARGET_DIR_PATH="${TARGET_DIR/%\//}"
FIND_ARGS=(
  "${TARGET_DIR_PATH}"
  -maxdepth 1
  -iname 'daily.*'
  -mtime "+${MAX_AGE}"
  -type d
)

# If there's no files to delete, that's ok
if ! (find "${FIND_ARGS[@]}" \
  | grep -v incomplete \
  | grep -q -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")"); then
  echo "No files to delete older then $MAX_AGE days."
  exit 0
fi

# print found files for logging
find "${FIND_ARGS[@]}" \
  | grep -v incomplete \
  | grep -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")" \
  | sort

# 1. Find all old backups
# 2. Exclude the current in progress folder
# 3. Exclude the current backup
# 4. remove found backups
find "${FIND_ARGS[@]}" \
  | grep -v incomplete \
  | grep -v "$(basename "$(readlink "${TARGET_DIR_PATH}/daily.current")")" \
  | sort \
  | xargs -t -r rm -rf
  echo "Files found to delete older then $MAX_AGE days. They are now deleted."
