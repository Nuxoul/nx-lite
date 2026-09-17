#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
COMMANDS_DIR=$ROOT/commands
TEMPLATES_DIR=$ROOT/templates
LIB_DIR=$ROOT/lib/nx

usage() {
  printf '%s\n' \
    'Usage: sh tools/sync-modules.sh [--check]' \
    '' \
    'Synchronize command templates and validate runtime source modules.' \
    'Without --check, generated files are updated. With --check, differences fail.'
}

check_only=0
case "${1:-}" in
  "") ;;
  --check) check_only=1 ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

for command_file in "$COMMANDS_DIR"/*; do
  [ -f "$command_file" ] || continue
  name=${command_file##*/}
  case "$name" in
    .*|*/*|*\\*|*..*)
      printf 'invalid command filename: %s\n' "$name" >&2
      exit 1
      ;;
  esac
  case "$name" in
    *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*)
      printf 'invalid command filename: %s\n' "$name" >&2
      exit 1
      ;;
  esac
  if grep -q '^NX_LITE_MODULE_EOF$' "$command_file"; then
    printf 'command contains reserved heredoc delimiter: %s\n' "$name" >&2
    exit 1
  fi
done

if [ "$check_only" -eq 0 ]; then
  mkdir -p "$TEMPLATES_DIR"
  for command_file in "$COMMANDS_DIR"/*; do
    [ -f "$command_file" ] || continue
    name=${command_file##*/}
    cp "$command_file" "$TEMPLATES_DIR/$name"
  done
  for template_file in "$TEMPLATES_DIR"/*; do
    [ -f "$template_file" ] || continue
    name=${template_file##*/}
    [ -f "$COMMANDS_DIR/$name" ] || rm -f "$template_file"
  done
else
  for command_file in "$COMMANDS_DIR"/*; do
    [ -f "$command_file" ] || continue
    name=${command_file##*/}
    if [ ! -f "$TEMPLATES_DIR/$name" ] || ! cmp -s "$command_file" "$TEMPLATES_DIR/$name"; then
      printf 'templates out of date: %s\n' "$name" >&2
      exit 1
    fi
  done
  for template_file in "$TEMPLATES_DIR"/*; do
    [ -f "$template_file" ] || continue
    name=${template_file##*/}
    if [ ! -f "$COMMANDS_DIR/$name" ]; then
      printf 'template has no command source: %s\n' "$name" >&2
      exit 1
    fi
  done
fi

for source_file in "$LIB_DIR/core.sh" "$LIB_DIR/ui.sh" "$LIB_DIR/default-modules.sh" "$LIB_DIR/lifecycle.sh"; do
  [ -f "$source_file" ] || {
    printf 'missing source module: %s\n' "$source_file" >&2
    exit 1
  }
done

if [ "$check_only" -eq 0 ]; then
  module_count=0
  for command_file in "$COMMANDS_DIR"/*; do
    [ -f "$command_file" ] || continue
    module_count=$((module_count + 1))
  done
  printf 'synchronized %s command modules\n' "$module_count"
fi
