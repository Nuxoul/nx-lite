command_description() {
  case "${1:-}" in
    angle) printf '%s' 'Convert degrees and radians' ;;
    base64) printf '%s' 'Encode or decode Base64' ;;
    base64-dec) printf '%s' 'Decode Base64 text' ;;
    base64-enc) printf '%s' 'Encode text as Base64' ;;
    color) printf '%s' 'Convert color formats' ;;
    guid) printf '%s' 'Generate GUIDs' ;;
    hash) printf '%s' 'Calculate file hashes' ;;
    json|json-pretty) printf '%s' 'Format JSON' ;;
    md5) printf '%s' 'Calculate MD5 hashes' ;;
    pow2) printf '%s' 'Work with powers of two' ;;
    url) printf '%s' 'Encode or decode URLs' ;;
    url-dec) printf '%s' 'Decode URL text' ;;
    url-enc) printf '%s' 'Encode text for URLs' ;;
    *) printf '%s' 'Installed nx-lite module' ;;
  esac
}

command_aliases() {
  case "${1:-}" in
    base64) printf '%s' 'b64' ;;
    base64-dec) printf '%s' 'b64d' ;;
    base64-enc) printf '%s' 'b64e' ;;
    guid) printf '%s' 'uuid' ;;
    hash) printf '%s' 'sha256' ;;
    json-pretty) printf '%s' 'jp' ;;
    pow2) printf '%s' 'p2' ;;
    url-dec) printf '%s' 'ud, urldecode' ;;
    url-enc) printf '%s' 'ue, urlencode' ;;
    *) printf '%s' '-' ;;
  esac
}

resolve_command() {
  case "${1:-}" in
    b64) printf '%s' 'base64' ;;
    b64d) printf '%s' 'base64-dec' ;;
    b64e) printf '%s' 'base64-enc' ;;
    jp) printf '%s' 'json-pretty' ;;
    p2) printf '%s' 'pow2' ;;
    ud|urldecode) printf '%s' 'url-dec' ;;
    ue|urlencode) printf '%s' 'url-enc' ;;
    uuid) printf '%s' 'guid' ;;
    sha256) printf '%s' 'hash' ;;
    *) printf '%s' "${1:-}" ;;
  esac
}

copy_to_clipboard() {
  [ "${NX_LITE_CLIP:-1}" != "0" ] || return 0

  if command -v clip.exe >/dev/null 2>&1; then
    printf '%s' "$1" | clip.exe >/dev/null 2>&1
  elif command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$1" | pbcopy >/dev/null 2>&1
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$1" | wl-copy >/dev/null 2>&1
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$1" | xclip -selection clipboard >/dev/null 2>&1
  elif command -v xsel >/dev/null 2>&1; then
    printf '%s' "$1" | xsel --clipboard --input >/dev/null 2>&1
  else
    return 0
  fi
}

usage() {
  printf '%snx-lite%s - modular terminal command toolbox\n' "$COLOR_BOLD" "$COLOR_RESET"
  printf 'version: %s\n\n' "$NX_LITE_VERSION"

  printf '%sUsage:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
  cat <<EOF
  nx <command> [args...]
  nx <command> --help
  nx init
  nx upgrade [raw-base-url]
  nx help [command]
  nx doctor
  nx completion <bash|zsh|powershell>
  nx path status
  nx mod <list|install|remove|info> [name]

EOF
  printf '%sModules:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
  print_command_list
  printf '\n%sExamples:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
  cat <<EOF
  nx base64 "hello"
  nx url "a b+c"
  nx json '{"name":"nx-lite"}'

Run 'nx <command> --help' for details.
EOF
}

completion_usage() {
  cat <<EOF
Usage:
  nx completion bash
  nx completion zsh
  nx completion powershell
EOF
}

completion() {
  shell=${1:-}
  case "$shell" in
    bash)
      cat <<'EOF'
_nx_complete() {
  local current="${COMP_WORDS[COMP_CWORD]}"
  local commands="angle base64 base64-dec base64-enc b64 b64d b64e color guid uuid hash sha256 json json-pretty jp md5 pow2 p2 url url-dec url-enc ud ue urlencode urldecode init upgrade doctor help list mod completion"
  COMPREPLY=( $(compgen -W "$commands" -- "$current") )
}
complete -F _nx_complete nx
EOF
      ;;
    zsh)
      cat <<'EOF'
_nx_complete() {
  local -a commands
  commands=(angle base64 base64-dec base64-enc b64 b64d b64e color guid uuid hash sha256 json json-pretty jp md5 pow2 p2 url url-dec url-enc ud ue urlencode urldecode init upgrade doctor help list mod completion)
  _describe 'nx command' commands
}
compdef _nx_complete nx
EOF
      ;;
    powershell)
      cat <<'EOF'
Register-ArgumentCompleter -CommandName nx,nx.cmd -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $commands = @(
    'angle', 'base64', 'base64-dec', 'base64-enc', 'b64', 'b64d', 'b64e',
    'color', 'guid', 'uuid', 'hash', 'sha256', 'json', 'json-pretty', 'jp',
    'md5', 'pow2', 'p2', 'url', 'url-dec', 'url-enc', 'ud', 'ue',
    'urlencode', 'urldecode', 'init', 'upgrade', 'doctor', 'help', 'list',
    'mod', 'completion'
  )
  $commands | Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_) }
}
EOF
      ;;
    *)
      completion_usage >&2
      exit 2
      ;;
  esac
}

doctor() {
  printf '%snx-lite doctor%s\n\n' "$COLOR_BOLD" "$COLOR_RESET"
  if command -v sh >/dev/null 2>&1; then
    printf '[ok] shell: %s\n' "$(command -v sh)"
  else
    printf '[fail] shell: not found\n'
  fi
  if command -v awk >/dev/null 2>&1; then
    printf '[ok] awk: %s\n' "$(command -v awk)"
  else
    printf '[fail] awk: not found\n'
  fi
  if [ -d "$NX_LITE_HOME" ]; then
    printf '[ok] nx home: %s\n' "$NX_LITE_HOME"
  else
    printf '[warn] nx home: missing (%s)\n' "$NX_LITE_HOME"
  fi
  if [ -d "$NX_LITE_COMMANDS_DIR" ]; then
    printf '[ok] command directory: %s\n' "$NX_LITE_COMMANDS_DIR"
  else
    printf '[warn] command directory: missing\n'
  fi
  if [ -d "$NX_LITE_TEMPLATES_DIR" ]; then
    printf '[ok] template directory: %s\n' "$NX_LITE_TEMPLATES_DIR"
  else
    printf '[warn] template directory: missing\n'
  fi
  case ":${PATH:-}:" in
    *":$NX_LITE_BIN_DIR:"*) printf '[ok] PATH contains %s\n' "$NX_LITE_BIN_DIR" ;;
    *) printf '[warn] PATH does not contain %s\n' "$NX_LITE_BIN_DIR" ;;
  esac
  if command -v clip.exe >/dev/null 2>&1 ||
    command -v pbcopy >/dev/null 2>&1 ||
    command -v wl-copy >/dev/null 2>&1 ||
    command -v xclip >/dev/null 2>&1 ||
    command -v xsel >/dev/null 2>&1; then
    printf '[ok] clipboard support detected\n'
  else
    printf '[warn] clipboard support unavailable\n'
  fi
  printf '\nRun `nx init` if setup is incomplete.\n'
}

mod_usage() {
  cat <<EOF
nx-lite module manager

Usage:
  nx mod list
  nx mod install <name>
  nx mod remove <name>
  nx mod info <name>
  nx mod --help

Install lookup order:
  1. Local template: $NX_LITE_TEMPLATES_DIR/<name>
  2. Built-in default module templates
  3. Remote URL when NX_LITE_REMOTE_BASE is set
EOF
}

