#!/usr/bin/env bash
# Post-bootstrap checks. Run inside the test container by inside.sh.
# Each phase adds its checks here. Exit status is non-zero if any check fails.
set -uo pipefail

fail=0
ok()   { echo "ok    $1"; }
bad()  { echo "FAIL  $1"; [ -n "${2:-}" ] && sed 's/^/      /' <<<"$2"; fail=1; }

# check DESC CMD... : passes if CMD exits 0
check() {
  local desc=$1; shift
  local out
  if out=$("$@" 2>&1); then ok "$desc"; else bad "$desc" "$out"; fi
}

# zcheck DESC ZSH-CODE : passes if the code exits 0 in an interactive zsh
zcheck() { check "$1" zsh -ic "$2"; }

echo "--- checks"
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/go/bin:$PATH"

# --- repo
check "dg status is clean" \
  test -z "$(git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" status --short)"

# --- home layout
check "~/d ~/p ~/w ~/t ~/s exist" test -d ~/d -a -d ~/p -a -d ~/w -a -d ~/t -a -d ~/s

# --- 10-zsh
check "login shell is zsh" \
  test "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)"
check "zsh plugins cloned" \
  test -d "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting"
check "zoxide installed" test -x "$HOME/.local/bin/zoxide"
check "local.zsh scaffolded" test -f "$HOME/.config/zsh/local.zsh"

startup=$(zsh -ic true 2>&1 </dev/null)
if [ -z "$startup" ]; then ok "zsh starts silently"; else bad "zsh starts silently" "$startup"; fi

zcheck "ZDOTDIR set"            '[[ $ZDOTDIR == $HOME/.config/zsh ]]'
zcheck "emacs keymap"           '[[ $(bindkey -lL main) == *emacs* ]]'
zcheck "compinit ran"           '(( $+functions[_main_complete] ))'
zcheck "autosuggestions loaded" '(( $+functions[_zsh_autosuggest_start] ))'
zcheck "syntax highlighting"    '(( $+ZSH_HIGHLIGHT_VERSION ))'
zcheck "z is a function"        '[[ $(whence -w z) == *function ]]'
zcheck "extract is a function"  '[[ $(whence -w extract) == *function ]]'
zcheck "dgs alias"              '[[ $(whence -w dgs) == *alias ]]'
zcheck "PATH has ~/.local/bin"  '[[ :$PATH: == *:$HOME/.local/bin:* ]]'
zcheck "EDITOR is nvim"         '[[ $EDITOR == nvim ]]'

# --- 20-tmux
check "tmux-resurrect cloned" \
  test -f "$HOME/.local/share/tmux/plugins/tmux-resurrect/resurrect.tmux"
tmux_err=$(TERM=xterm-256color tmux -L check new-session -d -s check 2>&1)
if [ -z "$tmux_err" ]; then ok "tmux starts with config"; else bad "tmux starts with config" "$tmux_err"; fi
check "tmux base-index 1"     test "$(tmux -L check show -gv base-index)" = 1
check "tmux mouse on"         test "$(tmux -L check show -gv mouse)" = on
check "tmux | splits"         sh -c 'tmux -L check list-keys | grep -q "prefix *| *split-window -h"'
check "tmux resurrect bound"  sh -c 'tmux -L check list-keys | grep -q resurrect'
tmux -L check kill-server 2>/dev/null

# --- 30-go, 40-go-tools
. /src/.bootstrap/versions.sh
check "go bootstrap present"   test -x "$HOME/sdk/$GO_BOOTSTRAP_VERSION/bin/go"
check "go-bootstrap link"      test "$(readlink "$HOME/sdk/go-bootstrap")" = "$HOME/sdk/$GO_BOOTSTRAP_VERSION"
check "go is tip"              sh -c 'go version | grep -q devel'
check "go fork remote"         sh -c 'git -C ~/w/go remote get-url fork | grep -q thatnealpatel'
check "gopls installed"        test -x "$HOME/go/bin/gopls"
check "gopls runs"             gopls version

# --- 50-neovim
nvim="$HOME/.local/bin/nvim"
check "nvim linked"            test -x "$nvim"
check "nvim is $NVIM_VERSION"  test "$("$nvim" --version | head -1)" = "NVIM $NVIM_VERSION"
check "nvim runs headless"     "$nvim" --headless -u NONE +q

# --- nvim config
nv() { "$nvim" --headless -c "lua io.write(tostring($1))" +qa 2>&1; }
startup=$("$nvim" --headless +qa 2>&1)
if [ -z "$startup" ]; then ok "nvim config loads silently"; else bad "nvim config loads silently" "$startup"; fi
check "no plugin dir"          test ! -d "$HOME/.local/share/nvim/site/pack"
check "fzf and rg on PATH"     sh -c 'command -v fzf && command -v rg'
check "colorscheme PaperColor" test "$(nv 'vim.g.colors_name')" = PaperColor
check "syntax off"             test "$(nv 'vim.g.syntax_on')" = nil
check ",sf mapped"             test "$(nv "vim.fn.maparg(',sf', 'n') ~= ''")" = true
check ",sg mapped"             test "$(nv "vim.fn.maparg(',sg', 'n') ~= ''")" = true
check "gopls configured"       test "$(nv 'vim.lsp.config.gopls.cmd[1]')" = gopls
check "completeopt"            test "$(nv 'vim.o.completeopt')" = 'menuone,noselect,popup,fuzzy'
check "fold text"              test "$(nv 'vim.o.foldtext')" = 'v:lua.FoldText()'
check "tag stack in statusline" sh -c "$nvim --headless -c 'lua io.write(vim.o.statusline)' +qa 2>&1 | grep -q TagStack"
check "TagStack() runs"        test "$(nv '_G.TagStack()')" = ""
# the picker end to end: ,sf with a fixed fzf filter picks the one matching file
picker=$(cd "$HOME" && mkdir -p pick && touch pick/alpha.txt pick/beta.txt \
  && FZF_DEFAULT_OPTS='--filter=alpha' "$nvim" --headless \
       -c "lua vim.fn.feedkeys(',sf', 'x')" \
       -c "lua vim.wait(5000, function() return vim.fn.expand('%:t') == 'alpha.txt' end)" \
       -c 'lua io.write(vim.fn.expand("%:t"))' +qa 2>&1)
if [ "$picker" = alpha.txt ]; then ok ",sf picks a file"; else bad ",sf picks a file" "$picker"; fi
# gopls attaches to a Go file in a fresh module
gomod=$(mktemp -d)
printf 'module x\n\ngo 1.25\n' >"$gomod/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$gomod/main.go"
attached=$(cd "$gomod" && "$nvim" --headless main.go \
  -c "lua vim.wait(20000, function() return #vim.lsp.get_clients({ name = 'gopls' }) > 0 end)" \
  -c "lua io.write(#vim.lsp.get_clients({ name = 'gopls' }))" +qa 2>&1)
if [ "$attached" = 1 ]; then ok "gopls attaches in nvim"; else bad "gopls attaches in nvim" "$attached"; fi

echo "--- prompt render"
zsh -ic 'print -P -- "$PS1"'
zcheck "no right prompt" '[[ -z $RPROMPT ]]'

echo "--- done, fail=$fail"
exit "$fail"
