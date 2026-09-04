# completion.zsh: compinit once, with the dump cached outside $HOME.

autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

zstyle ':completion:*' menu select                      # arrow through matches
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive
