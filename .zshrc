# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="papercolor"

plugins=(
	extract
	fasd
	history
	tmux
	zsh-completions
	zsh-autosuggestions
	zsh-syntax-highlighting
)

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#9e9e9e,underline"
autoload -U compinit && compinit
source $ZSH/oh-my-zsh.sh

# https://dev.to/cassidoo/customizing-my-zsh-prompt-3417
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%b '
setopt PROMPT_SUBST
git_prompt() {
  BRANCH=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/*\(.*\)/\1/')

  if [ ! -z $BRANCH ]; then
    echo -n "%F{244}$BRANCH"

    if [[ $(pwd) == *quarantine* ]]; then
      echo -n " %F{red}INTERNAL"
    fi

    STATUS=$(git status --short 2> /dev/null)

    if [ ! -z "$STATUS" ]; then
      echo " %F{red}✗"
    fi
  fi
}
PS1='
%F{red}$HOST
%F{blue}%~$(git_prompt)
%F{244}%# %F{reset}'


# edit cli in vi mode
autoload -z edit-command-line
zle -N edit-command-line
bindkey "^V^V" edit-command-line

#source $HOME/.oh-my-zsh/custom/plugins/async/async.zsh

# history settings
export HISTSIZE=20000 # general
export SAVEHIST=20000 # logout
export HISTFILE=~/.zhistory
setopt INC_APPEND_HISTORY # append only
setopt HIST_IGNORE_DUPS # duplicate not recorded
setopt EXTENDED_HISTORY # timestamps for entries

# aliases
alias dg="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
alias dgs="dg status"
alias dgc="dg commit"

alias gs="git status"
alias gc="git commit"

# some .bashrc stuff
alias la='ls -la'
alias gs='git status'
alias gc='git commit'


export HOMEBREW_NO_ANALYTICS=1 # no homebrew analytics
export GOPATH=$HOME/go
export PATH=$HOME/bin:$HOME/code/public/go/bin:$PATH:$HOME/go/bin
