#!/usr/bin/env bash
# 20-tmux: tmux plugins, loaded by ~/.config/tmux/tmux.conf.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 20-tmux"

plugins="$HOME/.local/share/tmux/plugins"
clone_or_update https://github.com/tmux-plugins/tmux-resurrect.git "$plugins/tmux-resurrect"
