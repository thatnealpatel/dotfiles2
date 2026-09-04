# plugins.zsh: third-party zsh plugins, cloned by .bootstrap/stages/10-zsh.sh.
# zsh-syntax-highlighting is sourced at the end of .zshrc, as it requires.

export ZSH_PLUGINS="$HOME/.local/share/zsh/plugins"

# extra completion definitions; must be on fpath before compinit runs
fpath=("$ZSH_PLUGINS/zsh-completions/src" $fpath)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#9e9e9e,underline"
[[ -r $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source "$ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"
