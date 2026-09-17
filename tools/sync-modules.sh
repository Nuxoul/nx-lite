#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
COMMANDS_DIR=$ROOT/commands
TEMPLATES_DIR=$ROOT/templates
ENTRYPOINT=$ROOT/bin/nx
BEGIN='# BEGIN GENERATED DEFAULT MODULES'
END='# END GENERATED DEFAULT MODULES'

usage() {
  printf '%s\n' \
    'Usage: sh tools/sync-modules.sh [--check]' \
    '' \
    'Synchronize templates and the embedded default modules in bin/nx.' \
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

tmp_dir=${TMPDIR:-/tmp}/nx-lite-sync.$$
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM
mkdir "$tmp_dir"

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

generated=$tmp_dir/nx
grep -q "^$BEGIN\$" "$ENTRYPOINT" || {
  printf 'missing generated module start marker: %s\n' "$ENTRYPOINT" >&2
  exit 1
}
grep -q "^$END\$" "$ENTRYPOINT" || {
  printf 'missing generated module end marker: %s\n' "$ENTRYPOINT" >&2
  exit 1
}
awk -v begin="$BEGIN" -v end="$END" '
  $0 == begin { found_begin = 1; exit }
  { print }
' "$ENTRYPOINT" > "$generated"

printf '%s\n' "$BEGIN" >> "$generated"
cat >> "$generated" <<'HEADER'
write_default_template() {
  name=$1
  target=$2

  case "$name" in
HEADER

for command_file in "$COMMANDS_DIR"/*; do
  [ -f "$command_file" ] || continue
  name=${command_file##*/}
  printf '    %s)\n      cat > "$target" <<'"'"'NX_LITE_MODULE_EOF'"'"'\n' "$name" >> "$generated"
  cat "$command_file" >> "$generated"
  printf '%s\n' 'NX_LITE_MODULE_EOF' '      ;;' >> "$generated"
done

cat >> "$generated" <<'FOOTER'
    *)
      return 1
      ;;
  esac

  chmod +x "$target" || die "failed to mark $target executable"
}
FOOTER
printf '%s\n' "$END" >> "$generated"

awk -v begin="$BEGIN" -v end="$END" '
  $0 == end { found_end = 1; next }
  found_end { print }
' "$ENTRYPOINT" >> "$generated"

if [ "$check_only" -eq 1 ]; then
  if ! cmp -s "$generated" "$ENTRYPOINT"; then
    printf 'embedded modules out of date: %s\n' "$ENTRYPOINT" >&2
    exit 1
  fi
else
  cp "$generated" "$ENTRYPOINT"
  chmod +x "$ENTRYPOINT"
fi

if [ "$check_only" -eq 0 ]; then
  module_count=0
  for command_file in "$COMMANDS_DIR"/*; do
    [ -f "$command_file" ] || continue
    module_count=$((module_count + 1))
  done
  printf 'synchronized %s command modules\n' "$module_count"
fi
