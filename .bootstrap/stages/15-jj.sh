#!/usr/bin/env bash
# 15-jj: pinned jujutsu binary and zsh completion into ~/.local.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 15-jj"

jj="$HOME/.local/bin/jj"
want=${JJ_VERSION#v}
# --version prints "jj 0.45.1-<commit>"; compare the part before the dash
if [ ! -x "$jj" ] || [ "$("$jj" --version | awk '{print $2}' | cut -d- -f1)" != "$want" ]; then
  log "jj $JJ_VERSION"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL --retry 3 \
    "https://github.com/jj-vcs/jj/releases/download/$JJ_VERSION/jj-$JJ_VERSION-$RUST_TARGET.tar.gz" \
    | tar -C "$HOME/.local/bin" -xzf - ./jj
  chmod 755 "$jj"
fi

# completion, regenerated each run so it matches the binary
mkdir -p "$HOME/.local/share/zsh/completions"
"$jj" util completion zsh >"$HOME/.local/share/zsh/completions/_jj"

log "jj -> $("$jj" --version)"
