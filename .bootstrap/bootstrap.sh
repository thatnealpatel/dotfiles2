#!/usr/bin/env bash
# Bootstrap a fresh Debian 13 x86_64 host into the full environment.
#
#   curl -fsSL https://raw.githubusercontent.com/thatnealpatel/dotfiles2/main/.bootstrap/bootstrap.sh | bash
#
# Re-runnable. With stage names, runs only those:
#   ~/.bootstrap/bootstrap.sh 30-go 50-neovim
#
# Flags:
#   -ts_authkey KEY  join the tailnet with this auth key (stage 05-tailscale).
#                    Also read from $TS_AUTHKEY. Via curl: bash -s -- -ts_authkey KEY
#
# Overrides, used by .bootstrap/test/run.sh:
#   DOTFILES_REPO  clone source          (default: github https url)
#   DOTFILES_REF   branch to check out   (default: main)
set -euo pipefail

TS_AUTHKEY="${TS_AUTHKEY:-}"
stages=()
while [ $# -gt 0 ]; do
  case $1 in
    -ts_authkey)   [ $# -ge 2 ] || { echo "-ts_authkey needs a key" >&2; exit 2; }
                   TS_AUTHKEY=$2; shift 2 ;;
    -ts_authkey=*) TS_AUTHKEY=${1#*=}; shift ;;
    -h|--help)     sed -n '2,15p' "$0" 2>/dev/null; exit 0 ;;
    -*)            echo "unknown flag: $1" >&2; exit 2 ;;
    *)             stages+=("$1"); shift ;;
  esac
done
export TS_AUTHKEY
set -- "${stages[@]}"

export DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/thatnealpatel/dotfiles2.git}"
export DOTFILES_PUSH="${DOTFILES_PUSH:-git@github.com:thatnealpatel/dotfiles2.git}"
export DOTFILES_REF="${DOTFILES_REF:-main}"
export DOTFILES_DIR="$HOME/.dotfiles"
export BOOTSTRAP_DIR="$HOME/.bootstrap"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

dg()      { git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }
log()     { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die()     { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

preflight() {
  [ -r /etc/os-release ] && . /etc/os-release
  [ "${ID:-}" = debian ] || die "targets Debian, found ${PRETTY_NAME:-unknown}"
  [ "$(uname -m)" = x86_64 ] || die "targets x86_64, found $(uname -m)"
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null || die "sudo is required for a non-root user"
    # stdin may be the script itself (curl | bash); prompt on the tty.
    if [ -r /dev/tty ]; then sudo -v </dev/tty; else sudo -n true; fi \
      || die "sudo access is required"
  fi
}

base_packages() {
  log "base packages"
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    --no-install-recommends git curl ca-certificates zsh >/dev/null
}

clone() {
  log "clone $DOTFILES_REPO -> $DOTFILES_DIR"
  git clone --quiet --bare --branch "$DOTFILES_REF" "$DOTFILES_REPO" "$DOTFILES_DIR"
  dg config status.showUntrackedFiles no
  dg config remote.origin.pushurl "$DOTFILES_PUSH"
  # A bare clone has no fetch refspec; add one so d2sync can pull.
  dg config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  dg fetch --quiet origin
  dg branch --quiet --set-upstream-to="origin/$DOTFILES_REF" "$DOTFILES_REF"
}

checkout() {
  log "checkout $DOTFILES_REF into $HOME"
  # Move aside anything the checkout would overwrite.
  local f moved=0
  while IFS= read -r f; do
    if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$f")"
      mv "$HOME/$f" "$BACKUP_DIR/$f"
      moved=1
    fi
  done < <(dg ls-tree -r --name-only "$DOTFILES_REF")
  [ "$moved" -eq 1 ] && log "existing files moved to $BACKUP_DIR"
  dg checkout --quiet
}

# Home layout, always present:
#   ~/d  downloads and other large things that should persist
#   ~/p  personal; all code lives here
#   ~/w  work
#   ~/t  temporary, but survives reboots
#   ~/s  security
scaffold_home() {
  mkdir -p "$HOME/d" "$HOME/p" "$HOME/w" "$HOME/t" "$HOME/s"
}

run_stages() {
  . "$BOOTSTRAP_DIR/lib.sh"
  . "$BOOTSTRAP_DIR/versions.sh"
  # shellcheck disable=SC2046
  apt_install $(sed 's/#.*//' "$BOOTSTRAP_DIR/apt-packages.txt")
  local s name
  for s in "$BOOTSTRAP_DIR"/stages/*.sh; do
    name=$(basename "$s" .sh)
    if [ $# -gt 0 ]; then
      case " $* " in
        *" $name "* | *" ${name%%-*} "*) ;;
        *) continue ;;
      esac
    fi
    bash "$s"
  done
}

main() {
  preflight
  if [ -d "$DOTFILES_DIR" ]; then
    log "repo present at $DOTFILES_DIR; skipping clone and checkout"
  else
    base_packages
    clone
    checkout
  fi
  scaffold_home
  run_stages "$@"
  log "done. start a new shell: exec zsh"
}

main "$@"
