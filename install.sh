#!/usr/bin/env bash
# Link this checkout into Neovim's config directory, preserving existing config.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--dry-run] [--help]

Link this checkout to ${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}.
Existing config is moved to a timestamped backup beside the destination.
Running again keeps an existing link or checkout in place.

  --dry-run  Show the destination and planned action without changing files.
  --help     Show this help.

This script configures Neovim only. Install Neovim and external tools separately;
lazy.nvim installs plugins on the first Neovim startup (network required).
USAGE
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
dry_run=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; fail "Unknown argument: $arg" ;;
  esac
done

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[[ -f "$repo_dir/init.lua" && -f "$repo_dir/lazy-lock.json" ]] || fail 'Run the script from a complete sentonvim checkout.'
config_home=${XDG_CONFIG_HOME:-"${HOME:?HOME must be set}/.config"}
app_name=${NVIM_APPNAME:-nvim}
[[ "$config_home" = /* ]] || fail 'XDG_CONFIG_HOME must be an absolute path.'
[[ "$app_name" != */* && "$app_name" != . && "$app_name" != .. ]] || fail 'NVIM_APPNAME must be a single directory name.'
target="${config_home%/}/$app_name"

printf 'Source: %s\nConfig: %s\n' "$repo_dir" "$target"
if [[ -d "$target" ]]; then
  target_real=$(cd -- "$target" && pwd -P)
  if [[ "$target_real" = "$repo_dir" ]]; then
    printf 'Already configured; no changes needed.\n'
    exit 0
  fi
  case "$repo_dir/" in
    "$target_real/"*) fail 'The checkout is inside the destination. Move it outside before installing.' ;;
  esac
fi

backup=''
if [[ -e "$target" || -L "$target" ]]; then
  backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
  suffix=0
  while [[ -e "$backup" || -L "$backup" ]]; do
    suffix=$((suffix + 1))
    backup="$target.backup.$(date +%Y%m%d-%H%M%S).$suffix"
  done
  printf 'Backup: %s\n' "$backup"
fi
if $dry_run; then
  printf 'Would create a symlink from Config to Source. No files changed.\n'
  exit 0
fi

mkdir -p -- "$config_home"
if [[ -n "$backup" ]]; then
  mv -- "$target" "$backup"
fi
if ! ln -s -- "$repo_dir" "$target"; then
  if [[ -n "$backup" ]]; then
    mv -- "$backup" "$target"
  fi
  fail 'Could not create the config link; any moved config has been restored.'
fi
printf 'Configured. Start nvim to install plugins; then run :checkhealth.\n'
if [[ -n "$backup" ]]; then
  printf 'To undo: remove only the symlink at %s, then move %s back.\n' "$target" "$backup"
fi
