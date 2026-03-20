#!/bin/sh
set -e

# Ensure important variables exist
USER="${USER:-$(id -u -n)}"
HOME="${HOME:-$(eval echo ~$USER)}"

# Default settings
CURSOR_COMMONS_HOME="${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}"
REMOTE="${REMOTE:-https://github.com/adinath/aifsd-commons.git}"
BRANCH="${BRANCH:-develop}"

# Options
UNATTENDED="${UNATTENDED:-no}"

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

is_tty() {
  [ -t 1 ]
}

setup_color() {
  if ! is_tty; then
    FMT_RED=""
    FMT_GREEN=""
    FMT_YELLOW=""
    FMT_BLUE=""
    FMT_BOLD=""
    FMT_RESET=""
    return
  fi
  FMT_RED="$(printf '\033[31m')"
  FMT_GREEN="$(printf '\033[32m')"
  FMT_YELLOW="$(printf '\033[33m')"
  FMT_BLUE="$(printf '\033[34m')"
  FMT_BOLD="$(printf '\033[1m')"
  FMT_RESET="$(printf '\033[0m')"
}

fmt_error() {
  printf '%sError: %s%s\n' "${FMT_BOLD}${FMT_RED}" "$*" "$FMT_RESET" >&2
}

get_shellrc() {
  if [ -f "$HOME/.bashrc" ]; then
    echo "$HOME/.bashrc"
  elif [ -f "$HOME/.zshrc" ]; then
    echo "$HOME/.zshrc"
  elif [ -f "$HOME/.profile" ]; then
    echo "$HOME/.profile"
  else
    echo "$HOME/.bashrc"
  fi
}

setup_cursor_commons() {
  umask g-w,o-w

  echo "${FMT_BLUE}Cloning Cursor Commons...${FMT_RESET}"

  command_exists git || {
    fmt_error "git is not installed"
    exit 1
  }

  if [ -d "$CURSOR_COMMONS_HOME" ]; then
    echo "${FMT_YELLOW}Directory $CURSOR_COMMONS_HOME already exists.${FMT_RESET}"
    if [ "$UNATTENDED" = "no" ] && is_tty; then
      printf "Do you want to reinstall/update? [Y/n] "
      read -r opt
      case "$opt" in
        [Nn]*) echo "Installation skipped."; return 1 ;;
      esac
    fi
    (cd "$CURSOR_COMMONS_HOME" && git fetch origin && git checkout -q "$BRANCH" && git pull --quiet origin "$BRANCH") || {
      fmt_error "Failed to update existing installation"
      exit 1
    }
  else
    git clone --branch "$BRANCH" --depth 1 "$REMOTE" "$CURSOR_COMMONS_HOME" || {
      fmt_error "git clone of cursor-commons failed"
      exit 1
    }
  fi
  echo
}

setup_cursor_dir() {
  echo "${FMT_BLUE}Setting up cursor-settings directory...${FMT_RESET}"

  OLD_CURSOR="$HOME/.cursor.pre-cursor-commons"
  if [ -d "$HOME/.cursor" ] || [ -L "$HOME/.cursor" ]; then
    if [ -e "$OLD_CURSOR" ]; then
      OLD_OLD="${OLD_CURSOR}-$(date +%Y-%m-%d_%H-%M-%S)"
      mv "$OLD_CURSOR" "$OLD_OLD"
      echo "${FMT_YELLOW}Backed up previous .cursor.pre-cursor-commons to $OLD_OLD${FMT_RESET}"
    fi
    mv "$HOME/.cursor" "$OLD_CURSOR"
    echo "${FMT_GREEN}Backed up existing .cursor to .cursor.pre-cursor-commons${FMT_RESET}"
  fi

  cp -r "$CURSOR_COMMONS_HOME/cursor-settings" "$HOME/.cursor"
  echo "${FMT_GREEN}Installed .cursor to $HOME/.cursor${FMT_RESET}"
  echo
}

setup_shellrc() {
  echo "${FMT_BLUE}Configuring shell...${FMT_RESET}"

  SHELLRC=$(get_shellrc)
  HOOK_MARKER="# Cursor Commons - shared Cursor IDE config"

  if [ -f "$SHELLRC" ]; then
    if grep -q "$HOOK_MARKER" "$SHELLRC" 2>/dev/null; then
      echo "${FMT_GREEN}Cursor Commons hook already present in $SHELLRC${FMT_RESET}"
    else
      cat >> "$SHELLRC" << 'HOOK_EOF'

# Cursor Commons - shared Cursor IDE config
if [ -d "${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}" ]; then
  export CURSOR_COMMONS_HOME="${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}"
  [ -f "$CURSOR_COMMONS_HOME/tools/check_for_upgrade.sh" ] && . "$CURSOR_COMMONS_HOME/tools/check_for_upgrade.sh"
  alias cursor-commons-update='sh "${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}/tools/upgrade.sh"'
fi
HOOK_EOF
      echo "${FMT_GREEN}Added Cursor Commons hook to $SHELLRC${FMT_RESET}"
    fi
  else
    mkdir -p "$(dirname "$SHELLRC")"
    cat >> "$SHELLRC" << 'HOOK_EOF'

# Cursor Commons - shared Cursor IDE config
if [ -d "${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}" ]; then
  export CURSOR_COMMONS_HOME="${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}"
  [ -f "$CURSOR_COMMONS_HOME/tools/check_for_upgrade.sh" ] && . "$CURSOR_COMMONS_HOME/tools/check_for_upgrade.sh"
  alias cursor-commons-update='sh "${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}/tools/upgrade.sh"'
fi
HOOK_EOF
    echo "${FMT_GREEN}Created $SHELLRC with Cursor Commons hook${FMT_RESET}"
  fi
  echo
}

print_success() {
  printf '\n'
  printf "${FMT_GREEN}${FMT_BOLD}Cursor Commons is now installed!${FMT_RESET}\n"
  printf '\n'
  printf "  ${FMT_BLUE}%s${FMT_RESET} %s\n" "•" "Cursor commands and rules are in $HOME/.cursor"
  printf "  ${FMT_BLUE}%s${FMT_RESET} %s\n" "•" "Update manually with: cursor-commons-update"
  printf "  ${FMT_BLUE}%s${FMT_RESET} %s\n" "•" "Restart your terminal or run: source $(get_shellrc)"
  printf '\n'
}

main() {
  if [ ! -t 0 ]; then
    UNATTENDED=yes
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --unattended) UNATTENDED=yes ;;
    esac
    shift
  done

  setup_color

  command_exists git || {
    fmt_error "git is not installed. Please install git first."
    exit 1
  }

  setup_cursor_commons || exit $?
  setup_cursor_dir
  setup_shellrc
  print_success
}

main "$@"
