# nx-lite

`nx-lite` is a small modular terminal command toolbox inspired by the x-cmd style of a single entrypoint plus independently installed command modules.

The unified command is:

```sh
nx <command> [args...]
```

## Project Tree

```text
nx-lite/
|-- bin/
|   `-- nx
|-- commands/
|   |-- base64
|   |-- base64-enc
|   |-- base64-dec
|   |-- angle
|   |-- color
|   |-- guid
|   |-- hash
|   |-- json
|   |-- json-pretty
|   |-- pow2
|   |-- url
|   |-- url-enc
|   |-- url-dec
|   `-- md5
|-- templates/
|   |-- base64
|   |-- base64-enc
|   |-- base64-dec
|   |-- angle
|   |-- color
|   |-- guid
|   |-- hash
|   |-- json
|   |-- json-pretty
|   |-- pow2
|   |-- url
|   |-- url-enc
|   |-- url-dec
|   `-- md5
|-- tests/
|   `-- smoke.sh
`-- README.md
```

After installation, the runtime layout is:

```text
~/
|-- .local/
|   `-- bin/
|       `-- nx
`-- .nx-lite/
    |-- commands/
    |   |-- base64
    |   |-- base64-enc
    |   |-- base64-dec
    |   |-- angle
    |   |-- color
    |   |-- guid
    |   |-- hash
    |   |-- json
    |   |-- json-pretty
    |   |-- pow2
    |   |-- url
    |   |-- url-enc
    |   |-- url-dec
    |   `-- md5
    `-- templates/
        |-- base64
        |-- base64-enc
        |-- base64-dec
        |-- angle
        |-- color
        |-- guid
        |-- hash
        |-- json
        |-- json-pretty
        |-- pow2
        |-- url
        |-- url-enc
        |-- url-dec
        `-- md5
```

## Files

`bin/nx` is the complete source for the target entrypoint `~/.local/bin/nx`. It is a POSIX `sh` script and includes:

- `nx init`
- `nx help` and `nx --help`
- `nx mod --help`
- `nx mod list`
- `nx mod install <name>`
- `nx mod remove <name>`
- command lookup and execution from `~/.nx-lite/commands/<name>`
- built-in default module templates
- reserved remote install support through `NX_LITE_REMOTE_BASE`

The default modules are executable POSIX `sh` scripts:

- `commands/base64`
- `commands/base64-enc`
- `commands/base64-dec`
- `commands/angle`
- `commands/color`
- `commands/guid`
- `commands/hash`
- `commands/json`
- `commands/json-pretty`
- `commands/pow2`
- `commands/url`
- `commands/url-enc`
- `commands/url-dec`
- `commands/md5`

The same default module files are also present in `templates/` so `nx mod install <name>` can copy local templates.

## Install

From Linux, macOS, or Windows WSL:

```sh
chmod +x bin/nx commands/* templates/*
sh ./bin/nx init
```

After publishing this repository to GitHub, install directly from the raw files:

```sh
curl -fsSL https://raw.githubusercontent.com/Nuxoul/nx-lite/main/install.sh | sh
```

Or with `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/Nuxoul/nx-lite/main/install.sh | sh
```

PowerShell bootstrap style:

```powershell
[System.Text.Encoding]::GetEncoding("utf-8").GetString($(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Nuxoul/nx-lite/main/install.ps1").RawContentStream.ToArray()) | Invoke-Expression
```

On Windows, the PowerShell installer writes three files into `~/.local/bin`:

- `nx`: the POSIX shell entrypoint
- `nx.cmd`: a PowerShell-friendly launcher
- `nx.ps1`: the launcher implementation

`nx.cmd` calls Git Bash to run the POSIX shell entrypoint, so PowerShell users can type `nx --help` directly after `~/.local/bin` is on `PATH`.

The launcher looks for Git Bash in standard Git for Windows locations, in Git for Windows registry entries, beside the `git.exe` found on `PATH`, and finally as `bash.exe` on `PATH`. For portable or unusual Git installs, set `NX_LITE_BASH` to the full `bash.exe` path:

```powershell
$env:NX_LITE_BASH = "D:\Program Files\Git\bin\bash.exe"
nx --help
```

Before publishing, or when using another branch/fork, override the raw base URL:

```sh
NX_LITE_RAW_BASE="https://raw.githubusercontent.com/Nuxoul/nx-lite/main" sh ./install.sh
```

```powershell
$env:NX_LITE_RAW_BASE = "https://raw.githubusercontent.com/Nuxoul/nx-lite/main"
[System.Text.Encoding]::GetEncoding("utf-8").GetString($(Invoke-WebRequest -Uri "$env:NX_LITE_RAW_BASE/install.ps1").RawContentStream.ToArray()) | Invoke-Expression
```

`nx init` creates:

- `~/.local/bin`
- `~/.nx-lite`
- `~/.nx-lite/commands`
- `~/.nx-lite/templates`

It copies the entrypoint to `~/.local/bin/nx`, installs the default modules, writes local templates, and prints a PATH hint if `~/.local/bin` is not already in `PATH`.

Runtime requirements:

- POSIX-compatible `sh`
- POSIX-compatible `awk`

The text modules do not require Python, pip packages, `base64`, `md5sum`, `openssl`, `jq`, `sed`, or other non-essential command tools. `nx hash` uses the platform hash tools already available on the system, such as `sha256sum`, `shasum`, `openssl`, or Windows `certutil.exe`.

If needed, add this to `~/.bashrc` or `~/.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## Verify

```sh
command -v nx
nx --help
nx mod list
```

Upgrade nx-lite later:

```sh
nx upgrade
```

Use another raw base URL, fork, or branch:

```sh
nx upgrade "https://raw.githubusercontent.com/Nuxoul/nx-lite/main"
```

Development smoke test:

```sh
sh tests/smoke.sh
```

Expected default modules:

```text
angle
base64
base64-dec
base64-enc
color
guid
hash
json
json-pretty
md5
pow2
url
url-dec
url-enc
```

## Usage Examples

```sh
nx base64 "hello"
```

```text
aGVsbG8=
```

```sh
nx base64 -d "SGVsbG8="
```

```text
Hello
```

```sh
nx url "a b+c"
```

```text
a%20b%2Bc
```

```sh
nx url -d "a%20b%2Bc"
```

```text
a b+c
```

```sh
nx json '{"a":1}'
```

```json
{
  "a": 1
}
```

Hash a file path. The default algorithm is SHA-256:

```sh
nx hash ./README.md
```

Use another algorithm:

```sh
nx hash md5 ./README.md
nx hash sha1 ./README.md
```

Generate a GUID:

```sh
nx guid
nx guid upper no-dash
```

Convert colors between hex, 0-255 RGB, and 0-1 float RGB:

```sh
nx color "#FF8040"
nx color rgb 255 128 64
nx color float 1 0.502 0.251
```

Work with power-of-two texture sizes:

```sh
nx pow2 300
nx pow2 down 300
nx pow2 check 512
```

Convert angles:

```sh
nx angle rad 90
nx angle deg 3.141592653589793
```

Compatibility aliases:

```sh
nx base64-enc "hello"
nx base64-dec "SGVsbG8="
nx json-pretty '{"a":1}'
nx url-enc "a b+c"
nx url-dec "a%20b%2Bc"
nx md5 "hello"
nx mod list
```

## Module Management

Upgrade the core entrypoint and default modules:

```sh
nx upgrade
```

Aliases are also accepted:

```sh
nx update
nx self-update
```

By default, upgrade downloads from:

```text
https://raw.githubusercontent.com/Nuxoul/nx-lite/main
```

Override it for forks or branches:

```sh
NX_LITE_RAW_BASE="https://raw.githubusercontent.com/<user>/<repo>/<branch>" nx upgrade
```

Or pass the URL directly:

```sh
nx upgrade "https://raw.githubusercontent.com/<user>/<repo>/<branch>"
```

List installed executable modules:

```sh
nx mod list
```

Install a module:

```sh
nx mod install <name>
```

Install lookup order:

1. `~/.nx-lite/templates/<name>`
2. built-in default templates in `~/.local/bin/nx`
3. remote URL when `NX_LITE_REMOTE_BASE` is set

Remove a module:

```sh
nx mod remove <name>
```

The module name is restricted to letters, digits, `.`, `_`, and `-`, and cannot include path separators. This keeps install and remove operations inside the configured module directory.

## Add A New Command

Example: `nx ascii-7bit`.

Create `~/.nx-lite/commands/ascii-7bit`:

```sh
#!/usr/bin/env sh

if [ "$#" -gt 0 ]; then
  NX_LITE_HAS_ARGS=1
  NX_LITE_INPUT=$*
else
  NX_LITE_HAS_ARGS=0
  NX_LITE_INPUT=
fi
export NX_LITE_HAS_ARGS NX_LITE_INPUT

LC_ALL=C awk '
function init_ord(    i) {
  for (i = 1; i < 128; i++) {
    ordv[sprintf("%c", i)] = i
  }
}

BEGIN {
  init_ord()
  from_args = (ENVIRON["NX_LITE_HAS_ARGS"] == "1")
  if (from_args) {
    text = ENVIRON["NX_LITE_INPUT"]
  }
}

!from_args {
  text = text (seen ? "\n" : "") $0
  seen = 1
}

END {
  for (i = 1; i <= length(text); i++) {
    if (!(substr(text, i, 1) in ordv)) {
      print "false"
      exit 1
    }
  }
  print "true"
}
'
```

Then:

```sh
chmod +x ~/.nx-lite/commands/ascii-7bit
nx ascii-7bit "hello"
```

To make it installable by name:

```sh
cp ~/.nx-lite/commands/ascii-7bit ~/.nx-lite/templates/ascii-7bit
nx mod remove ascii-7bit
nx mod install ascii-7bit
```

## Remote Module Repository Sketch

The current implementation reserves this interface:

```sh
NX_LITE_REMOTE_BASE="https://example.com/nx-lite/commands" nx mod install ascii-7bit
```

That downloads:

```text
https://example.com/nx-lite/commands/ascii-7bit
```

A simple future repository can be a static HTTP directory:

```text
repo/
|-- index.json
`-- commands/
    |-- ascii-7bit
    `-- uuid
```

Suggested `index.json` shape:

```json
{
  "modules": {
    "ascii-7bit": {
      "version": "0.1.0",
      "path": "commands/ascii-7bit",
      "sha256": "optional-checksum"
    }
  }
}
```

The next hardening step is to make `nx mod install` read `index.json`, resolve a module path, download to a temporary file, verify `sha256`, then move it into `~/.nx-lite/commands/`.
