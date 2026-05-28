#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SANDBOX="$ROOT/.sandbox"
HASH_FILE="$SANDBOX/hash-input.txt"

cd "$ROOT"
chmod +x bin/nx commands/* templates/*
rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"
printf 'hello' > "$HASH_FILE"

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

assert_not_contains() {
  haystack=$1
  needle=$2
  case "$haystack" in
    *"$needle"*)
      printf 'unexpected text: %s\n' "$needle" >&2
      printf '%s\n' "$haystack" >&2
      exit 1
      ;;
  esac
}

assert_eq 'aGVsbG8=' ./commands/base64-enc hello
assert_eq 'Hello' ./commands/base64-dec SGVsbG8=
assert_eq 'aGVsbG8=' ./commands/base64 hello
assert_eq 'Hello' ./commands/base64 -d SGVsbG8=
assert_eq 'Hello' ./commands/base64 decode SGVsbG8=
assert_eq 'a%20b%2Bc' ./commands/url 'a b+c'
assert_eq 'a b+c' ./commands/url -d 'a%20b%2Bc'
assert_eq 'a b+c' ./commands/url decode 'a%20b%2Bc'
assert_eq 'a%20b%2Bc' ./commands/url-enc 'a b+c'
assert_eq 'a b+c' ./commands/url-dec 'a%20b%2Bc'
assert_eq '5d41402abc4b2a76b9719d911017c592' ./commands/md5 hello
assert_eq '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824' ./commands/hash "$HASH_FILE"
assert_eq '5d41402abc4b2a76b9719d911017c592' ./commands/hash md5 "$HASH_FILE"
assert_eq '512' ./commands/pow2 300
assert_eq '256' ./commands/pow2 down 300
assert_eq 'true' ./commands/pow2 check 512
assert_eq 'false' ./commands/pow2 check 500
assert_eq '1.570796327' ./commands/angle rad 90
assert_eq '180' ./commands/angle deg 3.141592653589793

color_output=$(./commands/color '#FF8040')
color_expected='#FF8040
rgb 255 128 64
float 1.000 0.502 0.251'
if [ "$color_output" != "$color_expected" ]; then
  printf 'unexpected color output:\n%s\n' "$color_output" >&2
  exit 1
fi

guid_output=$(./commands/guid)
case "$guid_output" in
  ????????-????-????-????-????????????) ;;
  *)
    printf 'unexpected guid output: %s\n' "$guid_output" >&2
    exit 1
    ;;
esac

if command -v timeout >/dev/null 2>&1; then
  assert_eq 'aGVsbG8=' timeout 2 ./commands/base64-enc hello
  interactive_like_output=$(timeout 2 ./commands/base64-enc hello < /dev/zero)
  if [ "$interactive_like_output" != 'aGVsbG8=' ]; then
    printf 'base64-enc waited for stdin despite argv input\n' >&2
    exit 1
  fi
fi

json_output=$(./commands/json-pretty '{"a":1}')
json_expected='{
  "a": 1
}'
if [ "$json_output" != "$json_expected" ]; then
  printf 'unexpected json-pretty output:\n%s\n' "$json_output" >&2
  exit 1
fi

json_output=$(./commands/json '{"a":1}')
if [ "$json_output" != "$json_expected" ]; then
  printf 'unexpected json output:\n%s\n' "$json_output" >&2
  exit 1
fi

rm -rf "$SANDBOX"
mkdir -p "$SANDBOX"
printf 'hello' > "$HASH_FILE"

NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh ./bin/nx init >/dev/null

help_output=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx")
assert_contains "$help_output" 'nx-lite - modular terminal command toolbox'
assert_contains "$help_output" 'version:'
assert_contains "$help_output" 'nx upgrade [raw-base-url]'
assert_not_contains "$help_output" 'Available commands:'
assert_not_contains "$help_output" 'commands:'

unknown_output=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" __missing__ 2>&1 || true)
if [ "$unknown_output" != 'nx: command not found: __missing__' ]; then
  printf 'unexpected unknown command output:\n%s\n' "$unknown_output" >&2
  exit 1
fi

top_list=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" list)
assert_contains "$top_list" 'Installed nx-lite modules:'
assert_contains "$top_list" 'base64'

base64_usage=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64)
assert_contains "$base64_usage" 'Usage:'
assert_contains "$base64_usage" 'Example:'

assert_eq 'aGVsbG8=' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64-enc hello
assert_eq 'Hello' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64-dec SGVsbG8=
assert_eq 'aGVsbG8=' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64 hello
assert_eq 'Hello' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64 -d SGVsbG8=
assert_eq 'a%20b%2Bc' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" url 'a b+c'
assert_eq 'a b+c' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" url -d 'a%20b%2Bc'
assert_eq '5d41402abc4b2a76b9719d911017c592' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" md5 hello
assert_eq '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" hash "$HASH_FILE"
assert_eq '512' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" pow2 300
assert_eq '1.570796327' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" angle rad 90

module_list=$(env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" mod list)
assert_contains "$module_list" 'angle'
assert_contains "$module_list" 'base64'
assert_contains "$module_list" 'base64-enc'
assert_contains "$module_list" 'color'
assert_contains "$module_list" 'guid'
assert_contains "$module_list" 'hash'
assert_contains "$module_list" 'json'
assert_contains "$module_list" 'json-pretty'
assert_contains "$module_list" 'md5'
assert_contains "$module_list" 'pow2'
assert_contains "$module_list" 'url'

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
  assert_eq 'aGVsbG8=' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" base64 hello
  assert_eq 'a%20b%2Bc' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" url 'a b+c'
  assert_eq '512' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" pow2 300

  awk '
    /^DEFAULT_MODULES="/ {
      print "DEFAULT_MODULES=\"base64 base64-enc base64-dec json-pretty url-enc url-dec md5\""
      next
    }
    { print }
  ' "$SANDBOX/bin/nx" > "$SANDBOX/bin/nx.old-list"
  mv "$SANDBOX/bin/nx.old-list" "$SANDBOX/bin/nx"
  chmod +x "$SANDBOX/bin/nx"
  rm -f "$SANDBOX/nx-lite/commands/pow2" "$SANDBOX/nx-lite/templates/pow2"

  env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" upgrade "$raw_base" >/dev/null
  assert_eq '512' env NX_LITE_HOME="$SANDBOX/nx-lite" NX_LITE_BIN_DIR="$SANDBOX/bin" sh "$SANDBOX/bin/nx" pow2 300
  rm -rf "$RAW_SANDBOX"
fi

printf 'smoke tests passed\n'
