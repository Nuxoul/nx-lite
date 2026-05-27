#!/usr/bin/env sh

set -eu

DEFAULT_RAW_BASE="https://raw.githubusercontent.com/Nuxoul/nx-lite/main"
RAW_BASE=${1:-${NX_LITE_RAW_BASE:-$DEFAULT_RAW_BASE}}

NX_LITE_HOME=${NX_LITE_HOME:-$HOME/.nx-lite}
NX_LITE_BIN_DIR=${NX_LITE_BIN_DIR:-$HOME/.local/bin}
ENTRYPOINT="$NX_LITE_BIN_DIR/nx"

die() {
  printf 'nx-lite installer: %s\n' "$*" >&2
  exit 1
}

fetch() {
  url=$1
  target=$2
  tmp="$target.tmp.$$"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp" || {
      rm -f "$tmp"
      die "failed to download $url"
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$url" || {
      rm -f "$tmp"
      die "failed to download $url"
    }
  else
    die "curl or wget is required to download nx-lite"
  fi

  mv "$tmp" "$target" || die "failed to write $target"
}

case "$RAW_BASE" in
  *YOUR_GITHUB_USERNAME*)
    die "set NX_LITE_RAW_BASE or pass the GitHub raw base URL before installing"
    ;;
esac

mkdir -p "$NX_LITE_BIN_DIR" "$NX_LITE_HOME" || die "failed to create install directories"

fetch "${RAW_BASE%/}/bin/nx" "$ENTRYPOINT"
chmod +x "$ENTRYPOINT" || die "failed to mark $ENTRYPOINT executable"

sh "$ENTRYPOINT" init

printf '\nInstall complete. Try:\n'
printf '  nx --help\n'
printf '  nx base64-enc "hello"\n'
