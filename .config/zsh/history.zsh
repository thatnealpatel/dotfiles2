# history.zsh

export HISTFILE="$HOME/.zhistory"
export HISTSIZE=20000   # in memory
export SAVEHIST=20000   # on disk

setopt INC_APPEND_HISTORY   # write as commands run, not at exit
setopt HIST_IGNORE_DUPS     # skip consecutive duplicates
setopt EXTENDED_HISTORY     # timestamps and durations
