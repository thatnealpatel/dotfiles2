# aliases.zsh: aliases and small functions.

# d2sync [stage...]: fast-forward $HOME to origin/main, then re-run
# the named bootstrap stages, if any. Edits happen in a normal clone, never
# here; a tracked file changed in $HOME makes the pull refuse, on purpose.
d2sync() {
  git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" pull --ff-only || return
  if (( $# )); then "$HOME/.bootstrap/bootstrap.sh" "$@"; fi
}

alias gs='git status'
alias gc='git commit'

alias ls='ls --color=auto'
alias la='ls -la'

# extract FILE...: unpack by extension into the current directory.
extract() {
  local f
  for f in "$@"; do
    if [[ ! -f $f ]]; then print -u2 "extract: no such file: $f"; continue; fi
    case $f in
      *.tar.gz|*.tgz)   tar xzf "$f" ;;
      *.tar.xz|*.txz)   tar xJf "$f" ;;
      *.tar.bz2|*.tbz2) tar xjf "$f" ;;
      *.tar.zst)        tar --zstd -xf "$f" ;;
      *.tar)            tar xf "$f" ;;
      *.gz)             gunzip -k "$f" ;;
      *.xz)             unxz -k "$f" ;;
      *.bz2)            bunzip2 -k "$f" ;;
      *.zip)            unzip -q "$f" ;;
      *.7z)             7z x "$f" ;;
      *)                print -u2 "extract: unknown format: $f" ;;
    esac
  done
}
