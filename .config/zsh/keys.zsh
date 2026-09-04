# keys.zsh: line editor keymap and bindings.

# zsh picks the vi keymap whenever $EDITOR contains "vi", which "nvim" does.
# oh-my-zsh used to force emacs; keep that.
bindkey -e

# ^V^V opens the current command line in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^V^V' edit-command-line

# up/down search history by the prefix already typed
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

bindkey '^[[H' beginning-of-line   # home
bindkey '^[[F' end-of-line         # end
bindkey '^[[3~' delete-char        # delete
