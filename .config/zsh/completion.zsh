# completion.zsh: compinit once, with the dump cached outside $HOME.
# -C skips the insecure-directory audit; everything on fpath is ours.

autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

zstyle ':completion:*' menu select                      # arrow through matches
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive
