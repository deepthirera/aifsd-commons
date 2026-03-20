#!/bin/sh
#
# Cursor Commons - upgrade script
# Pulls latest from remote and syncs cursor-settings to home directory.
#

set -e

CURSOR_COMMONS_HOME="${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}"

if [ ! -d "$CURSOR_COMMONS_HOME" ]; then
  echo "Error: Cursor Commons not found at $CURSOR_COMMONS_HOME" >&2
  echo "Run the install script first." >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || {
  echo "Error: git is not installed" >&2
  exit 1
}

echo "Updating Cursor Commons..."
cd "$CURSOR_COMMONS_HOME"
git pull

MAX_BACKUPS=5

prune_old_backups() {
  ls -dt "$HOME/.cursor.backup-"* 2>/dev/null \
    | tail -n "+$((MAX_BACKUPS + 1))" \
    | while IFS= read -r old; do
        rm -rf "$old"
        echo "Removed old backup: $old"
      done
}

echo "Syncing cursor-settings to $HOME/.cursor..."
if [ -d "$HOME/.cursor" ] || [ -L "$HOME/.cursor" ]; then
  BACKUP="$HOME/.cursor.backup-$(date +%Y-%m-%d_%H-%M-%S)"
  cp -r "$HOME/.cursor" "$BACKUP"
  echo "Backed up existing .cursor to $BACKUP"
  prune_old_backups
fi
mkdir -p "$HOME/.cursor"
cp -r cursor-settings/. "$HOME/.cursor/"

echo "Cursor Commons has been updated successfully."

printf '\n'
