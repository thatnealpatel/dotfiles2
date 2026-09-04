# .zshrc: one file per purpose, sourced in dependency order.
#   path        PATH, GOPATH, editor
#   history     history file and options
#   plugins     fpath for completions, autosuggestions   (before compinit)
#   completion  compinit, completion style
#   keys        keymap and bindings
#   prompt      two-line prompt with git state
#   aliases     aliases and small functions
#   tools       personal tool env, zoxide, tool managers
#   local       host-specific, untracked, sourced last so it can override

for f in path history plugins completion keys prompt aliases tools; do
  source "$ZDOTDIR/$f.zsh"
done
unset f

[[ -r $ZDOTDIR/local.zsh ]] && source "$ZDOTDIR/local.zsh"

# Must be sourced last: it wraps every zle widget defined above.
[[ -r $ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source "$ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
