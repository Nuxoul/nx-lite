install_entrypoint() {
  target="$NX_LITE_BIN_DIR/nx"
  self_path=$0

  if [ ! -f "$self_path" ]; then
    self_path=$(command -v "$0" 2>/dev/null || true)
  fi

  if [ -n "$self_path" ] && [ -r "$self_path" ]; then
    if [ "$self_path" != "$target" ]; then
      cp "$self_path" "$target" || die "failed to install entrypoint to $target"
    fi
    chmod +x "$target" || die "failed to mark $target executable"
    printf 'installed entrypoint: %s\n' "$target"
  else
    printf 'nx: warning: could not locate current script; create %s manually\n' "$target" >&2
  fi
}

runtime_files="core.sh ui.sh default-modules.sh lifecycle.sh"

install_runtime() {
  runtime_dir="$NX_LITE_HOME/runtime"
  mkdir -p "$runtime_dir" || die "failed to create runtime directory"

  for runtime_file in $runtime_files; do
    target="$runtime_dir/$runtime_file"
    if [ -n "${NX_LITE_SOURCE_ROOT:-}" ] && [ -f "$NX_LITE_SOURCE_ROOT/lib/nx/$runtime_file" ]; then
      cp "$NX_LITE_SOURCE_ROOT/lib/nx/$runtime_file" "$target" ||
        die "failed to install runtime file $runtime_file"
    elif [ -s "$target" ]; then
      :
    else
      download_url "${NX_LITE_RAW_BASE%/}/lib/nx/$runtime_file" "$target" ||
        die "failed to download runtime file $runtime_file"
    fi
    chmod +x "$target" || die "failed to mark runtime file executable"
  done
}

install_default_modules() {
  for name in $DEFAULT_MODULES; do
    template="$NX_LITE_TEMPLATES_DIR/$name"
    command_file="$NX_LITE_COMMANDS_DIR/$name"

    write_default_template "$name" "$template"

    if [ -e "$command_file" ]; then
      printf 'kept existing module: %s\n' "$name"
    else
      cp "$template" "$command_file" || die "failed to install module $name"
      chmod +x "$command_file" || die "failed to mark $command_file executable"
      printf 'installed module: %s\n' "$name"
    fi
  done
}

print_path_hint() {
  case ":${PATH:-}:" in
    *":$NX_LITE_BIN_DIR:"*) return 0 ;;
  esac

  cat <<EOF

Notice:
  $NX_LITE_BIN_DIR is not in PATH.

Add this line to ~/.bashrc or ~/.zshrc, then restart the shell:
  export PATH="\$HOME/.local/bin:\$PATH"
EOF
}

nx_init() {
  ensure_dirs
  install_entrypoint
  install_runtime
  install_default_modules
  print_path_hint
  printf '\nnx-lite initialized.\n'
}

download_url() {
  url=$1
  target=$2
  tmp="$target.download.$$"
  attempt=1
  last_error=1

  while [ "$attempt" -le 3 ]; do
    rm -f "$tmp"
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL "$url" -o "$tmp"; then
        last_error=0
      else
        last_error=1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -qO "$tmp" "$url"; then
        last_error=0
      else
        last_error=1
      fi
    else
      rm -f "$tmp"
      die "upgrade needs curl or wget"
    fi

    if [ "$last_error" -eq 0 ] && [ -s "$tmp" ]; then
      mv "$tmp" "$target" || {
        rm -f "$tmp"
        return 1
      }
      return 0
    fi

    rm -f "$tmp"
    attempt=$((attempt + 1))
    sleep 1
  done

  return 1
}

nx_upgrade() {
  raw_base=${1:-$NX_LITE_RAW_BASE}
  raw_base=${raw_base%/}
  [ -n "$raw_base" ] || die "usage: nx upgrade [raw-base-url]"

  ensure_dirs
  stage="$NX_LITE_HOME/.upgrade.$$"
  backup="$NX_LITE_HOME/.backup.$$"
  rm -rf "$stage"
  mkdir -p "$stage/runtime" "$stage/commands" "$stage/templates" ||
    die "failed to create upgrade staging directory"

  cleanup_upgrade() {
    rm -rf "$stage"
  }

  printf 'upgrading nx-lite from: %s\n' "$raw_base"
  replace_entrypoint=0
  if [ ! -f "$NX_LITE_BIN_DIR/nx" ] || ! grep -q "NX_LITE_RUNTIME_DIR" "$NX_LITE_BIN_DIR/nx"; then
    replace_entrypoint=1
    download_url "$raw_base/bin/nx" "$stage/nx" || { cleanup_upgrade; die "failed to download nx entrypoint"; }
    chmod +x "$stage/nx" || { cleanup_upgrade; die "failed to mark staged entrypoint executable"; }
  fi

  for runtime_file in $runtime_files; do
    download_url "$raw_base/lib/nx/$runtime_file" "$stage/runtime/$runtime_file" || {
      cleanup_upgrade
      die "failed to download runtime file $runtime_file"
    }
    chmod +x "$stage/runtime/$runtime_file" || {
      cleanup_upgrade
      die "failed to mark runtime file executable"
    }
  done

  modules=$DEFAULT_MODULES
  if download_url "$raw_base/manifest" "$stage/manifest" 2>/dev/null; then
    if new_modules=$(awk -F= '$1 == "modules" { print $2; found=1; exit } END { if (!found) exit 1 }' "$stage/manifest"); then
      modules=$(printf '%s' "$new_modules" | tr ',' ' ')
    fi

    fi
  for name in $modules; do
    valid_module_name "$name" || {
      cleanup_upgrade
      die "invalid module name in upgrade manifest: $name"
    }
    download_url "$raw_base/commands/$name" "$stage/commands/$name" || {
      cleanup_upgrade
      die "failed to download module $name"
    }
    download_url "$raw_base/templates/$name" "$stage/templates/$name" || {
      cleanup_upgrade
      die "failed to download template $name"
    }
    chmod +x "$stage/commands/$name" "$stage/templates/$name" || {
      cleanup_upgrade
      die "failed to mark module $name executable"
    }
  done

  if [ -d "$NX_LITE_COMMANDS_DIR" ]; then
    for old_command in "$NX_LITE_COMMANDS_DIR"/*; do
      [ -f "$old_command" ] || continue
      old_name=${old_command##*/}
      case " $modules " in
        *" $old_name "*) ;;
        *)
          cp "$old_command" "$stage/commands/$old_name" || die "failed to preserve module $old_name"
          if [ -f "$NX_LITE_TEMPLATES_DIR/$old_name" ]; then
            cp "$NX_LITE_TEMPLATES_DIR/$old_name" "$stage/templates/$old_name" || die "failed to preserve template $old_name"
          fi
          ;;
      esac
    done
  fi

  mkdir -p "$backup"
  rm -rf "$NX_LITE_HOME/runtime.next"
  mv "$stage/runtime" "$NX_LITE_HOME/runtime.next" || die "failed to stage runtime activation"
  [ ! -e "$NX_LITE_COMMANDS_DIR" ] || mv "$NX_LITE_COMMANDS_DIR" "$backup/commands"
  [ ! -e "$NX_LITE_TEMPLATES_DIR" ] || mv "$NX_LITE_TEMPLATES_DIR" "$backup/templates"
  mv "$stage/commands" "$NX_LITE_COMMANDS_DIR" || die "failed to activate commands"
  mv "$stage/templates" "$NX_LITE_TEMPLATES_DIR" || die "failed to activate templates"
  if [ "$replace_entrypoint" -eq 1 ]; then
    cp "$stage/nx" "$NX_LITE_BIN_DIR/nx" || die "failed to activate entrypoint"
    chmod +x "$NX_LITE_BIN_DIR/nx"
  fi
  chmod +x "$NX_LITE_BIN_DIR/nx"
  if [ -f "$stage/manifest" ]; then
    cp "$stage/manifest" "$NX_LITE_HOME/manifest"
  fi
  cleanup_upgrade

  printf 'updated entrypoint: %s\n' "$NX_LITE_BIN_DIR/nx"
  printf 'updated runtime: %s files\n' "$(printf '%s\n' $runtime_files | wc -l | awk '{print $1}')"
  printf 'updated modules: %s\n' "$(printf '%s\n' $modules | wc -l | awk '{print $1}')"
  printf '\nnx-lite upgraded.\n'
}

download_remote_module() {
  name=$1
  target=$2

  [ -n "$NX_LITE_REMOTE_BASE" ] || return 1

  url="${NX_LITE_REMOTE_BASE%/}/$name"
  tmp="$target.download.$$"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp" || {
      rm -f "$tmp"
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$url" || {
      rm -f "$tmp"
      return 1
    }
  else
    printf 'nx: remote install needs curl or wget\n' >&2
    return 1
  fi

  mv "$tmp" "$target" || {
    rm -f "$tmp"
    return 1
  }
  chmod +x "$target" || return 1
  return 0
}

mod_list() {
  printf 'Installed nx-lite modules:\n'
  print_command_list
}

mod_info() {
  name=$(resolve_command "${1:-}")
  [ -n "$name" ] || die "usage: nx mod info <name>"
  valid_module_name "$name" || die "invalid module name: $name"
  if [ ! -f "$NX_LITE_COMMANDS_DIR/$name" ]; then
    die "module not installed: $name"
  fi

  printf 'Name:        %s\n' "$name"
  printf 'Description: %s\n' "$(command_description "$name")"
  printf 'Aliases:     %s\n' "$(command_aliases "$name")"
  printf 'Location:    %s\n' "$NX_LITE_COMMANDS_DIR/$name"
  printf '\nExample:\n'
  case "$name" in
    base64) printf '  nx b64 "hello"\n' ;;
    base64-dec) printf '  nx b64d "aGVsbG8="\n' ;;
    color) printf '  nx color "#FF8040"\n' ;;
    guid) printf '  nx uuid\n' ;;
    hash) printf '  nx sha256 ./file\n' ;;
    json|json-pretty) printf '  nx jp '\''{"name":"nx-lite"}'\''\n' ;;
    pow2) printf '  nx p2 300\n' ;;
    url|url-enc) printf '  nx ue "a b+c"\n' ;;
    url-dec) printf '  nx ud "a%%20b"\n' ;;
    *) printf '  nx %s --help\n' "$name" ;;
  esac
}

path_status() {
  case ":${PATH:-}:" in
    *":$NX_LITE_BIN_DIR:"*)
      printf '[ok] PATH contains %s\n' "$NX_LITE_BIN_DIR"
      ;;
    *)
      printf '[warn] PATH does not contain %s\n' "$NX_LITE_BIN_DIR"
      printf '\nPowerShell (current session):\n'
      printf '  $env:Path = "%s;$env:Path"\n' "$NX_LITE_BIN_DIR"
      printf '\nPOSIX shell (current session):\n'
      printf '  export PATH="%s:$PATH"\n' "$NX_LITE_BIN_DIR"
      return 1
      ;;
  esac
}

mod_install() {
  name=${1:-}
  [ -n "$name" ] || die "usage: nx mod install <name>"
  valid_module_name "$name" || die "invalid module name: $name"

  ensure_dirs

  target="$NX_LITE_COMMANDS_DIR/$name"
  template="$NX_LITE_TEMPLATES_DIR/$name"

  if [ -e "$target" ]; then
    printf 'module already installed: %s\n' "$name"
    return 0
  fi

  if [ -f "$template" ]; then
    cp "$template" "$target" || die "failed to install module $name from local template"
    chmod +x "$target" || die "failed to mark $target executable"
    printf 'installed module from local template: %s\n' "$name"
    return 0
  fi

  if is_default_module "$name"; then
    write_default_template "$name" "$target" || die "failed to install built-in module $name"
    printf 'installed built-in module: %s\n' "$name"
    return 0
  fi

  if download_remote_module "$name" "$target"; then
    printf 'installed module from remote: %s\n' "$name"
    return 0
  fi

  die "module not found: $name (local template missing; remote install not configured or failed)"
}

mod_remove() {
  name=${1:-}
  [ -n "$name" ] || die "usage: nx mod remove <name>"
  valid_module_name "$name" || die "invalid module name: $name"

  target="$NX_LITE_COMMANDS_DIR/$name"
  if [ ! -f "$target" ]; then
    die "module not installed: $name"
  fi

  rm -f "$target" || die "failed to remove module $name"
  printf 'removed module: %s\n' "$name"
}

mod_main() {
  sub=${1:-}
  case "$sub" in
    ""|help|--help|-h)
      mod_usage
      ;;
    list)
      mod_list
      ;;
    install)
      shift
      mod_install "${1:-}"
      ;;
    info)
      shift
      mod_info "${1:-}"
      ;;
    remove|rm|uninstall)
      shift
      mod_remove "${1:-}"
      ;;
    *)
      printf 'nx: unknown mod command: %s\n\n' "$sub" >&2
      mod_usage >&2
      exit 1
      ;;
  esac
}

run_module() {
  cmd=$1
  shift

  script="$NX_LITE_COMMANDS_DIR/$cmd"
  if [ -f "$script" ] && [ -x "$script" ]; then
    if [ "$#" -eq 0 ]; then
      case "$cmd" in
        guid)
          ;;
        *)
          "$script" --help
          exit $?
          ;;
      esac
    fi

    output=$("$script" "$@")
    status=$?
    if [ "$status" -eq 0 ]; then
      if [ -n "$output" ]; then
        printf '%s\n' "$output"
        copy_to_clipboard "$output"
      fi
    else
      if [ -n "$output" ]; then
        printf '%s\n' "$output"
      fi
    fi
    exit "$status"
  fi

  printf 'nx: command not found: %s\n' "$cmd" >&2
  exit 127
}

show_module_help() {
  cmd=$1
  script="$NX_LITE_COMMANDS_DIR/$cmd"
  if [ -f "$script" ] && [ -x "$script" ]; then
    "$script" --help
    exit $?
  fi

  printf 'nx: command not found: %s\n' "$cmd" >&2
  exit 127
}

main() {
  init_colors

  if [ "${1:-}" = "--no-clip" ]; then
    NX_LITE_CLIP=0
    export NX_LITE_CLIP
    shift
  fi

  cmd=${1:-}
  case "$cmd" in
    ""|--help|-h)
      usage
      ;;
    help)
      shift
      if [ "${1:-}" = "mod" ]; then
        mod_usage
      elif [ -n "${1:-}" ]; then
        help_command=$(resolve_command "$1")
        show_module_help "$help_command"
      else
        usage
      fi
      ;;
    version|--version|-v)
      printf '%s\n' "$NX_LITE_VERSION"
      ;;
    doctor)
      doctor
      ;;
    completion)
      shift
      completion "${1:-}"
      ;;
    path)
      shift
      case "${1:-status}" in
        status) path_status ;;
        *) die "usage: nx path status" ;;
      esac
      ;;
    list|ls)
      mod_list
      ;;
    init)
      nx_init
      ;;
    upgrade|update|self-update)
      shift
      nx_upgrade "${1:-}"
      ;;
    mod)
      shift
      mod_main "$@"
      ;;
    *)
      cmd=$(resolve_command "$cmd")
      shift
      run_module "$cmd" "$@"
      ;;
  esac
}

