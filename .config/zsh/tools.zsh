# tools.zsh: environment for personal tools and third-party tool managers.
# Everything here is the same on every host. Hostnames, IPs, and secrets go
# in local.zsh.

# personal tools
export YAH_DEBUG=1
export FINDINGS_CACHE_DIR="$HOME/.goof/db/findings"
export GH_CACHE_DIR="$HOME/d/gh"
export GERRIT_CACHE_DIR="$HOME/d/gerrit"
export RFC_CACHE_DIR="$HOME/d/rfc"
export WHATWG_CACHE_DIR="$HOME/d/whatwg"
export OEIS_CACHE_DIR="$HOME/d/oeis"
export WIKI_CACHE_DIR="$HOME/d/wiki"
export ERDOS_CACHE_DIR="$HOME/d/erdos"
export CVE_CACHE_DIR="$HOME/d/cve"
export LEANDOC_DOT_LAKE="$HOME/p/proofs/.lake"

# zoxide: z DIR, zi for interactive. Replaces fasd.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# tool managers, each only if installed
[[ -d $HOME/.elan/bin ]] && path=("$HOME/.elan/bin" $path)

[[ -r $HOME/.opam/opam-init/init.zsh ]] \
  && source "$HOME/.opam/opam-init/init.zsh" >/dev/null 2>&1

export NVM_DIR="$HOME/.nvm"
[[ -s $NVM_DIR/nvm.sh ]] && source "$NVM_DIR/nvm.sh"

GCLOUD_SDK="$HOME/.local/google-cloud-sdk"
[[ -r $GCLOUD_SDK/path.zsh.inc ]] && source "$GCLOUD_SDK/path.zsh.inc"
[[ -r $GCLOUD_SDK/completion.zsh.inc ]] && source "$GCLOUD_SDK/completion.zsh.inc"
