#!/usr/bin/env bash
# 50-neovim: build the pinned release from its source tarball.
#
#   source   ~/.cache/nvim-src/neovim-<ver>/      (kept, so rebuilds are incremental)
#   install  ~/.local/nvim/<ver>/                 (one dir per version; old ones stay)
#   link     ~/.local/bin/nvim -> the pinned version
#
# Roll back by pointing the link at an older ~/.local/nvim/<ver>/bin/nvim.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 50-neovim"

ver=$NVIM_VERSION
prefix="$HOME/.local/nvim/$ver"
srcroot="$HOME/.cache/nvim-src"
src="$srcroot/neovim-${ver#v}"
logfile="$srcroot/build-$ver.log"

if [ -x "$prefix/bin/nvim" ] && "$prefix/bin/nvim" --version | head -1 | grep -q "NVIM $ver"; then
  log "neovim $ver already built"
else
  if [ ! -f "$src/CMakeLists.txt" ]; then
    log "fetch neovim $ver source"
    mkdir -p "$srcroot"
    curl -fsSL --retry 3 "https://github.com/neovim/neovim/archive/refs/tags/$ver.tar.gz" \
      | tar -C "$srcroot" -xzf -
  fi
  log "build neovim $ver ($(nproc) jobs, log: $logfile)"
  if ! ( cd "$src" \
         && make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$prefix" -j"$(nproc)" \
         && make install ) >"$logfile" 2>&1; then
    tail -n 40 "$logfile" >&2
    die "neovim build failed, full log: $logfile"
  fi
fi

link "$prefix/bin/nvim" "$HOME/.local/bin/nvim"
log "nvim -> $("$HOME/.local/bin/nvim" --version | head -1)"

# ~/bin precedes ~/.local/bin on PATH; a stale nvim there shadows this build
if [ -e "$HOME/bin/nvim" ] && [ "$(readlink -f "$HOME/bin/nvim")" != "$(readlink -f "$prefix/bin/nvim")" ]; then
  warn "$HOME/bin/nvim shadows the new build; remove it"
fi
