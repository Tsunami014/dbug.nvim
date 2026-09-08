#!/usr/bin/env bash
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export XDG_DATA_HOME="$dir/.local/share"
export XDG_STATE_HOME="$dir/.local/state"
export XDG_CACHE_HOME="$dir/.local/cache"

gotodir="$dir/../testdir/"
mkdir -p "$gotodir"
cd "$gotodir"
exec nvim -u "$dir/init.lua" ./main.md
