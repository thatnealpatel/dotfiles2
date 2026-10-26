# path.zsh: PATH, Go roots, editor.

export GOPATH="$HOME/go"
# Pinned release toolchain used to build tip, managed by stages/30-go.sh.
export GOROOT_BOOTSTRAP="$HOME/d/go"

typeset -U path   # no duplicates
# Homebrew is not necessarily on PATH in a fresh macOS shell.
if [[ $OSTYPE == darwin* ]]; then
  path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
fi
path=("$HOME/bin" "$HOME/.local/bin" $path "$GOPATH/bin")

export VISUAL=nvim
export EDITOR=nvim
