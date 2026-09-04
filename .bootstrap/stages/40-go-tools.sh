#!/usr/bin/env bash
# 40-go-tools: go install every module in go-tools.txt with the tip toolchain.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 40-go-tools"

go="$HOME/bin/go"
[ -x "$go" ] || die "no $go; run 30-go first"

# Never download a different toolchain to satisfy a module's go directive.
export GOTOOLCHAIN=local
export GOPATH="$HOME/go"

sed 's/#.*//' "$BOOTSTRAP_DIR/go-tools.txt" | while read -r mod; do
  [ -z "$mod" ] && continue
  log "go install $mod"
  "$go" install "$mod"
done
