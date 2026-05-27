#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SANDBOX="$ROOT/.sandbox"

cd "$ROOT"
chmod +x bin/nx commands/* templates/*

assert_eq() {
  expected=$1
  shift
  actual=$("$@")
  if [ "$actual" != "$expected" ]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  haystack=$1
  needle=$2
  case "$haystack" in
    *"$needle"*) ;;
    *)
      printf 'missing expected text: %s\n' "$needle" >&2
      printf '%s\n' "$haystack" >&2
      exit 1
      ;;
  esac
}

assert_eq 'aGVsbG8=' ./commands/base64-enc hello
assert_eq 'Hello' ./commands/base64-dec SGVsbG8=
assert_eq 'a%20b%2Bc' ./commands/url-enc 'a b+c'
assert_eq 'a b+c' ./commands/url-dec 'a%20b%2Bc'
assert_eq '5d41402abc4b2a76b9719d911017c592' ./commands/md5 hello

json_output=$(./commands/json-pretty '{"a":1}')
json_expected='{
  "a": 1
}'
if [ "$json_output" != "$json_expected" ]; then
  printf 'unexpected json-pretty output:\n%s\n' "$json_output" >&2
  exit 1
fi

rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"

NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh ./bin/nx init >/dev/null

assert_eq 'aGVsbG8=' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64-enc hello
assert_eq 'Hello' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64-dec SGVsbG8=
assert_eq '5d41402abc4b2a76b9719d911017c592' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" md5 hello

module_list=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" mod list)
assert_contains "$module_list" 'base64-enc'
assert_contains "$module_list" 'json-pretty'
assert_contains "$module_list" 'md5'

if command -v curl >/dev/null 2>&1; then
  RAW_SANDBOX="/tmp/nx-lite-smoke-$$"
  rm -rf "$RAW_SANDBOX"
  mkdir -p "$RAW_SANDBOX"
  cp -R "$ROOT/bin" "$ROOT/commands" "$RAW_SANDBOX/"
  if raw_path=$(cd "$RAW_SANDBOX" && pwd -W 2>/dev/null); then
    raw_path=$(printf '%s' "$raw_path" | awk '{ gsub(/ /, "%20"); print }')
    raw_base="file:///$raw_path"
  else
    raw_base="file://$RAW_SANDBOX"
  fi
  env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" upgrade "$raw_base" >/dev/null
  assert_eq 'aGVsbG8=' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64-enc hello
  rm -rf "$RAW_SANDBOX"
fi

printf 'smoke tests passed\n'
