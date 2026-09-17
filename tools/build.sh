#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DIST=$ROOT/dist/nx-lite

usage() {
  printf '%s\n' \
    'Usage: sh tools/build.sh [--check]' \
    '' \
    'Build the multi-file nx-lite runtime package.' \
    'Use --check to validate sources without changing dist/.'
}

case "${1:-}" in
  --check)
    sh "$ROOT/tools/sync-modules.sh" --check
    for file in bin/nx lib/nx/core.sh lib/nx/ui.sh lib/nx/default-modules.sh lib/nx/lifecycle.sh; do
      [ -f "$ROOT/$file" ] || {
        printf 'missing package file: %s\n' "$file" >&2
        exit 1
      }
    done
    ;;
  ""|--write)
    sh "$ROOT/tools/sync-modules.sh"
    rm -rf "$DIST"
    mkdir -p "$DIST/runtime" "$DIST/commands" "$DIST/templates"
    cp "$ROOT/bin/nx" "$DIST/nx"
    cp "$ROOT"/lib/nx/*.sh "$DIST/runtime/"
    cp "$ROOT"/commands/* "$DIST/commands/"
    cp "$ROOT"/templates/* "$DIST/templates/"
    chmod +x "$DIST/nx" "$DIST"/runtime/*.sh "$DIST"/commands/* "$DIST"/templates/*
    version=$(awk -F= '/^NX_LITE_VERSION=/ {
      value=$2
      sub(/^.*:-/, "", value)
      sub(/}.*/, "", value)
      print value
      exit
    }' "$ROOT/lib/nx/core.sh")
    modules=$(awk -F'"' '/^DEFAULT_MODULES="/ { print $2; exit }' "$ROOT/lib/nx/core.sh" | tr ' ' ',')
    [ -n "$modules" ] || {
      printf 'could not read default module list\n' >&2
      exit 1
    }
    {
      printf 'version=%s\n' "$version"
      printf 'runtime=runtime\n'
      printf 'modules=%s\n' "$modules"
      printf 'commands=commands\n'
      printf 'templates=templates\n'
    } > "$DIST/manifest"
    printf 'built package: %s\n' "$DIST"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
