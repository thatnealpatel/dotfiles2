# aliases.zsh: aliases and small functions.

# the bare dotfiles repo checked out over $HOME
alias dg='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'
alias dgs='dg status'
alias dgc='dg commit'

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
