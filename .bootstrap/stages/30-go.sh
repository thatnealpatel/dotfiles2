#!/usr/bin/env bash
# 30-go: Go from tip.
#
#   ~/d/go                 pinned release, only used to build tip; $GOROOT_BOOTSTRAP
#   ~/w/go                 clone of go.googlesource.com/go, built in place
#   ~/bin/go, ~/bin/gofmt  symlinks into ~/w/go/bin
#
# ~/w/go is never pulled by this script: it is a working tree. Re-run after
# pulling to rebuild. The build is skipped when HEAD matches the last build.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 30-go"

boot="$HOME/d/go"
tip="$HOME/w/go"
built="$HOME/.cache/go-tip-built-rev"
logfile="$HOME/.cache/go-tip-build.log"

# bootstrap toolchain. Whatever is at ~/d/go that is not exactly the pinned
# version is replaced.
if [ ! -x "$boot/bin/go" ] || [ "$(head -1 "$boot/VERSION" 2>/dev/null)" != "$GO_BOOTSTRAP_VERSION" ]; then
  log "go $GO_BOOTSTRAP_VERSION -> $boot"
  rm -rf "$boot"
  mkdir -p "$boot"
  curl -fsSL --retry 3 "https://go.dev/dl/$GO_BOOTSTRAP_VERSION.linux-amd64.tar.gz" \
    | tar -C "$boot" --strip-components=1 -xzf -
fi

# tip source
if [ ! -d "$tip/.git" ]; then
  log "clone go tip -> $tip"
  mkdir -p "$(dirname "$tip")"
  git clone --quiet https://go.googlesource.com/go "$tip"
fi
git -C "$tip" remote get-url fork >/dev/null 2>&1 \
  || git -C "$tip" remote add fork git@github.com:thatnealpatel/go.git

# build when missing or stale
head=$(git -C "$tip" rev-parse HEAD)
if [ ! -x "$tip/bin/go" ] || [ "$(cat "$built" 2>/dev/null)" != "$head" ]; then
  log "build go tip at ${head:0:12} (log: $logfile)"
  mkdir -p "$(dirname "$logfile")"
  if ! ( cd "$tip/src" && GOROOT_BOOTSTRAP="$boot" ./make.bash ) >"$logfile" 2>&1; then
    tail -n 40 "$logfile" >&2
    die "go build failed, full log: $logfile"
  fi
  echo "$head" >"$built"
fi

link "$tip/bin/go" "$HOME/bin/go"
link "$tip/bin/gofmt" "$HOME/bin/gofmt"
log "go -> $("$HOME/bin/go" version)"
