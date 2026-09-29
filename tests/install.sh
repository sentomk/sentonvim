#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/sentonvim-install.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
fixture="$work/checkout with spaces"
mkdir -p "$fixture"
cp "$repo_dir/install.sh" "$fixture/install.sh"
printf 'return {}\n' > "$fixture/init.lua"
printf '{}\n' > "$fixture/lazy-lock.json"

run_install() {
  XDG_CONFIG_HOME="$work/config home" NVIM_APPNAME=nvim bash "$fixture/install.sh" "$@"
}
target="$work/config home/nvim"
run_install --dry-run >/dev/null
[[ ! -e "$work/config home" ]]
run_install >/dev/null
[[ -L "$target" && "$(readlink "$target")" = "$fixture" ]]
run_install >/dev/null
[[ $(find "$work/config home" -name '*.backup.*' | wc -l) -eq 0 ]]
# A checkout already installed directly must not move itself.
XDG_CONFIG_HOME="$work" NVIM_APPNAME='checkout with spaces' bash "$fixture/install.sh" >/dev/null
[[ -f "$fixture/init.lua" && ! -L "$fixture" ]]

rm "$target"
mkdir "$target"
printf 'keep this config\n' > "$target/old.lua"
run_install >/dev/null
backup=$(find "$work/config home" -maxdepth 1 -name 'nvim.backup.*')
[[ -L "$target" && -f "$backup/old.lua" ]]
[[ "$(cat "$backup/old.lua")" = 'keep this config' ]]

# Preserve a broken symlink as a symlink, including its original destination.
rm "$target"
ln -s "$work/not-present" "$target"
run_install >/dev/null
found=false
for entry in "$work/config home"/nvim.backup.*; do
  if [[ -L "$entry" && "$(readlink "$entry")" = "$work/not-present" ]]; then found=true; fi
done
$found

# A regular file is also backed up without losing its content.
rm "$target"
printf 'old file\n' > "$target"
run_install >/dev/null
found=false
for entry in "$work/config home"/nvim.backup.*; do
  if [[ -f "$entry" && "$(cat "$entry")" = 'old file' ]]; then found=true; fi
done
$found

if XDG_CONFIG_HOME=relative NVIM_APPNAME=nvim bash "$fixture/install.sh" >/dev/null 2>&1; then exit 1; fi
if XDG_CONFIG_HOME="$work/config home" NVIM_APPNAME=../unsafe bash "$fixture/install.sh" >/dev/null 2>&1; then exit 1; fi
if run_install --unknown >/dev/null 2>&1; then exit 1; fi
if XDG_CONFIG_HOME="$work" NVIM_APPNAME='.' bash "$fixture/install.sh" >/dev/null 2>&1; then exit 1; fi
# Refuse to move a directory that contains this checkout.
if XDG_CONFIG_HOME="$(dirname "$work")" NVIM_APPNAME="$(basename "$work")" bash "$fixture/install.sh" >/dev/null 2>&1; then exit 1; fi

# If creating the link fails, restore the old config.
rm "$target"
mkdir "$target" "$work/bin"
printf 'keep on failure\n' > "$target/old.lua"
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/bin/ln"
chmod +x "$work/bin/ln"
if PATH="$work/bin:$PATH" run_install >/dev/null 2>&1; then exit 1; fi
[[ ! -L "$target" && "$(cat "$target/old.lua")" = 'keep on failure' ]]
printf 'PASS: dry run, spaces, fresh install, repeat, in-place checkout, backups, invalid paths, rollback\n'
