#!/bin/sh
#
# Cursor Commons - check for upgrades
# Sourced from .bashrc/.zshrc when CURSOR_COMMONS_HOME is set.
# Compares local MANIFEST version with remote; prompts if update available.
#

# Only run if CURSOR_COMMONS_HOME is set and directory exists
[ -z "${CURSOR_COMMONS_HOME}" ] && return 0
[ ! -d "$CURSOR_COMMONS_HOME" ] && return 0

# Skip if not a git repo or git unavailable
command -v git >/dev/null 2>&1 || return 0
(cd "$CURSOR_COMMONS_HOME" && git rev-parse --is-inside-work-tree >/dev/null 2>&1) || return 0

# Check if update checking is disabled
[ "${CURSOR_COMMONS_UPDATE_DISABLED}" = "1" ] && return 0

# Update frequency in days (default: 14)
FREQ="${CURSOR_COMMONS_UPDATE_DAYS:-14}"
LAST_CHECK_FILE="$CURSOR_COMMONS_HOME/.last-update-check"

# Get current epoch in days
current_epoch() {
  if [ -n "$EPOCHSECONDS" ]; then
    echo $((EPOCHSECONDS / 60 / 60 / 24))
  else
    date +%s | awk '{print int($1/86400)}'
  fi
}

# Parse VERSION=1.2.3 from MANIFEST
get_version() {
  grep -E '^VERSION=' "$1" 2>/dev/null | cut -d= -f2 | tr -d ' \r\n'
}

# Returns 0 if $1 > $2 (version_gt)
version_gt() {
  v1="$1"
  v2="$2"
  [ -z "$v1" ] && v1="0.0.0"
  [ -z "$v2" ] && v2="0.0.0"

  maj1=$(echo "$v1" | cut -d. -f1); min1=$(echo "$v1" | cut -d. -f2); pat1=$(echo "$v1" | cut -d. -f3)
  maj2=$(echo "$v2" | cut -d. -f1); min2=$(echo "$v2" | cut -d. -f2); pat2=$(echo "$v2" | cut -d. -f3)

  maj1=${maj1:-0}; min1=${min1:-0}; pat1=${pat1:-0}
  maj2=${maj2:-0}; min2=${min2:-0}; pat2=${pat2:-0}

  [ "$maj2" -gt "$maj1" ] && return 0
  [ "$maj2" -lt "$maj1" ] && return 1
  [ "$min2" -gt "$min1" ] && return 0
  [ "$min2" -lt "$min1" ] && return 1
  [ "$pat2" -gt "$pat1" ] && return 0
  [ "$pat2" -lt "$pat1" ] && return 1
  return 1
}

# Check if enough time has passed
LAST_EPOCH=""
[ -f "$LAST_CHECK_FILE" ] && . "$LAST_CHECK_FILE" 2>/dev/null
CURR=$(current_epoch)
if [ -n "$LAST_EPOCH" ] && [ "$((CURR - LAST_EPOCH))" -lt "$FREQ" ]; then
  return 0
fi

# Fetch remote (ignore errors - network may be down)
(cd "$CURSOR_COMMONS_HOME" && git fetch origin 2>/dev/null) || true

# Get branch
BRANCH=$(cd "$CURSOR_COMMONS_HOME" && git symbolic-ref --short HEAD 2>/dev/null || echo "develop")
REMOTE_REF="origin/$BRANCH"

# Get remote MANIFEST version
REMOTE_VERSION=$(cd "$CURSOR_COMMONS_HOME" && git show "$REMOTE_REF:MANIFEST" 2>/dev/null | grep -E '^VERSION=' | cut -d= -f2 | tr -d ' \r\n')
LOCAL_VERSION=$(get_version "$CURSOR_COMMONS_HOME/MANIFEST")

# Update last check time
echo "LAST_EPOCH=$CURR" > "$LAST_CHECK_FILE"

# Compare versions: prompt if remote > local
if [ -n "$REMOTE_VERSION" ] && version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
  : # Remote is newer - fall through to prompt
else
  return 0  # No update or couldn't determine
fi

# Remote is newer - prompt user
printf '\n'
printf '[cursor-commons] A new version is available!\n'
printf '  Local:  %s\n' "${LOCAL_VERSION:-unknown}"
printf '  Remote: %s\n' "$REMOTE_VERSION"
printf '  Run \033[1mcursor-commons-update\033[0m to upgrade.\n'
printf '\n'
