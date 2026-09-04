# path.zsh: PATH, Go roots, editor.

export GOPATH="$HOME/go"
# Stable symlink to the pinned release toolchain, managed by stages/40-go.sh.
export GOROOT_BOOTSTRAP="$HOME/sdk/go-bootstrap"

typeset -U path   # no duplicates
path=("$HOME/bin" "$HOME/.local/bin" $path "$GOPATH/bin")

export VISUAL=nvim
export EDITOR=nvim
