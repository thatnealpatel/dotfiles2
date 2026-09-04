#!/usr/bin/env bash
# 10-zsh: zsh plugins, zoxide, local.zsh scaffold, login shell.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 10-zsh"

# plugins, sourced by ~/.config/zsh/plugins.zsh and .zshrc
plugins="$HOME/.local/share/zsh/plugins"
for p in zsh-autosuggestions zsh-completions zsh-syntax-highlighting; do
  clone_or_update "https://github.com/zsh-users/$p.git" "$plugins/$p"
done

# zoxide: static binary from the pinned release
zoxide="$HOME/.local/bin/zoxide"
want=${ZOXIDE_VERSION#v}
if [ ! -x "$zoxide" ] || [ "$("$zoxide" --version | awk '{print $2}')" != "$want" ]; then
  log "zoxide $ZOXIDE_VERSION"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL --retry 3 \
    "https://github.com/ajeetdsouza/zoxide/releases/download/$ZOXIDE_VERSION/zoxide-$want-x86_64-unknown-linux-musl.tar.gz" \
    | tar -C "$HOME/.local/bin" -xzf - zoxide
  chmod 755 "$zoxide"
fi

# host-specific config, scaffolded once and never overwritten
local_zsh="$HOME/.config/zsh/local.zsh"
if [ ! -f "$local_zsh" ]; then
  cp "$HOME/.config/zsh/local.zsh.example" "$local_zsh"
  log "scaffolded $local_zsh"
fi

# login shell
user=$(id -un)
zsh=$(command -v zsh)
if [ "$(getent passwd "$user" | cut -d: -f7)" != "$zsh" ]; then
  log "login shell -> $zsh"
  as_root chsh -s "$zsh" "$user"
fi
