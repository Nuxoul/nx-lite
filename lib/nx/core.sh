#!/usr/bin/env sh

set -u

NX_LITE_HOME=${NX_LITE_HOME:-$HOME/.nx-lite}
NX_LITE_BIN_DIR=${NX_LITE_BIN_DIR:-$HOME/.local/bin}
NX_LITE_COMMANDS_DIR=${NX_LITE_COMMANDS_DIR:-$NX_LITE_HOME/commands}
NX_LITE_TEMPLATES_DIR=${NX_LITE_TEMPLATES_DIR:-$NX_LITE_HOME/templates}
NX_LITE_REMOTE_BASE=${NX_LITE_REMOTE_BASE:-}
NX_LITE_RAW_BASE=${NX_LITE_RAW_BASE:-https://raw.githubusercontent.com/Nuxoul/nx-lite/main}
NX_LITE_VERSION=${NX_LITE_VERSION:-0.5.0}
NX_LITE_CLIP=${NX_LITE_CLIP:-1}
NX_LITE_COLOR=${NX_LITE_COLOR:-auto}

COLOR_RESET=
COLOR_BOLD=
COLOR_CYAN=
COLOR_YELLOW=
COLOR_RED=

init_colors() {
  case "$NX_LITE_COLOR" in
    1|always) use_color=1 ;;
    0|never) use_color=0 ;;
    *)
      use_color=0
      if { [ -t 1 ] ||
        [ -n "${WT_SESSION:-}" ] ||
        [ "${TERM_PROGRAM:-}" = "Windows_Terminal" ] ||
        [ "${ConEmuANSI:-}" = "ON" ]; } && [ -z "${NO_COLOR:-}" ]; then
        use_color=1
      fi
      ;;
  esac

  if [ "$use_color" -eq 1 ] && [ -z "${NO_COLOR:-}" ]; then
    COLOR_RESET=$(printf '\033[0m')
    COLOR_BOLD=$(printf '\033[1m')
    COLOR_CYAN=$(printf '\033[36m')
    COLOR_YELLOW=$(printf '\033[33m')
    COLOR_RED=$(printf '\033[31m')
  fi
}

DEFAULT_MODULES="base64 base64-enc base64-dec angle color guid hash json json-pretty pow2 url url-enc url-dec md5"

die() {
  printf '%snx:%s %s%s\n' "$COLOR_RED" "$COLOR_RESET" "$*" "$COLOR_RESET" >&2
  exit 1
}

ensure_dirs() {
  mkdir -p "$NX_LITE_BIN_DIR" "$NX_LITE_HOME" "$NX_LITE_COMMANDS_DIR" "$NX_LITE_TEMPLATES_DIR" \
    || die "failed to create nx-lite directories"
}

valid_module_name() {
  case "${1:-}" in
    ""|.*|*/*|*\\*|*..*) return 1 ;;
  esac

  case "$1" in
    *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) return 1 ;;
  esac

  return 0
}

is_default_module() {
  case "${1:-}" in
    base64|base64-enc|base64-dec|angle|color|guid|hash|json|json-pretty|pow2|url|url-enc|url-dec|md5) return 0 ;;
    *) return 1 ;;
  esac
}

list_commands() {
  [ -d "$NX_LITE_COMMANDS_DIR" ] || return 0

  for file in "$NX_LITE_COMMANDS_DIR"/*; do
    [ -f "$file" ] || continue
    [ -x "$file" ] || continue
    name=${file##*/}
    case "$name" in
      .*|"") continue ;;
    esac
    printf '%s\n' "$name"
  done | sort
}

print_command_list() {
  commands=$(list_commands)
  if [ -n "$commands" ]; then
    printf '%s\n' "$commands" | while IFS= read -r name; do
      aliases=$(command_aliases "$name")
      if [ "$aliases" = "-" ]; then
        printf '  %-12s %s\n' "$name" "$(command_description "$name")"
      else
        printf '  %-12s %-28s aliases: %s\n' "$name" "$(command_description "$name")" "$aliases"
      fi
    done
  else
    printf '  (no commands installed; run nx init)\n'
  fi
}

