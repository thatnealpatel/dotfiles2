# tools.zsh: environment for personal tools and third-party tool managers.
# Everything here is the same on every host. Hostnames, IPs, and secrets go
# in local.zsh.

# personal tools
export RFC_CACHE_DIR="$HOME/d/rfc"
export WHATWG_CACHE_DIR="$HOME/d/whatwg"
export OEIS_CACHE_DIR="$HOME/d/oeis"
export WIKI_CACHE_DIR="$HOME/d/wiki"
export ERDOS_CACHE_DIR="$HOME/d/erdos"
export LEANDOC_DOT_LAKE="$HOME/p/proofs/.lake"

# personal intranet
export GRFA_PROXY="http://supermarket:9001"
export GHFA_PROXY="http://gas-station:9001"
export RETRIEVAL_HOST="http://supermarket:9001"

# yah
export YAH_DEBUG=1
export YAH_IGNORED_PROVIDERS="Makora:OpenInference:Sail Research"

# claude
export CLAUDE_CODE_DISABLE_CRON=1
export CLAUDE_CODE_DISABLE_ARTIFACT=1
export CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1
export CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1
export ENABLE_CLAUDEAI_MCP_SERVERS=false
export CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS=1

# zoxide: z DIR, zi for interactive. Replaces fasd.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# tool managers, each only if installed
[[ -d $HOME/.elan/bin ]] && path=("$HOME/.elan/bin" $path)

[[ -r $HOME/.opam/opam-init/init.zsh ]] \
  && source "$HOME/.opam/opam-init/init.zsh" >/dev/null 2>&1

# nvm costs ~300ms to load, so it loads on first use of any of its commands.
export NVM_DIR="$HOME/.nvm"
if [[ -s $NVM_DIR/nvm.sh ]]; then
  _nvm_load() {
    unfunction nvm node npm npx corepack 2>/dev/null
    source "$NVM_DIR/nvm.sh"
  }
  nvm()      { _nvm_load; nvm "$@" }
  node()     { _nvm_load; node "$@" }
  npm()      { _nvm_load; npm "$@" }
  npx()      { _nvm_load; npx "$@" }
  corepack() { _nvm_load; corepack "$@" }
fi

GCLOUD_SDK="$HOME/.local/google-cloud-sdk"
[[ -r $GCLOUD_SDK/path.zsh.inc ]] && source "$GCLOUD_SDK/path.zsh.inc"
[[ -r $GCLOUD_SDK/completion.zsh.inc ]] && source "$GCLOUD_SDK/completion.zsh.inc"
