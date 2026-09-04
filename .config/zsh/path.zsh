# path.zsh: PATH, Go roots, editor.

export GOPATH="$HOME/go"
# Pinned release toolchain used to build tip, managed by stages/30-go.sh.
export GOROOT_BOOTSTRAP="$HOME/d/go"

typeset -U path   # no duplicates
path=("$HOME/bin" "$HOME/.local/bin" $path "$GOPATH/bin")

export VISUAL=nvim
export EDITOR=nvim
