# shellcheck shell=bash
# Shared helpers for bootstrap stages. Source, do not execute.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BOOTSTRAP_DIR="${BOOTSTRAP_DIR:-$HOME/.bootstrap}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Standalone stages cannot trust an inherited platform override. Keep this
# selection and Homebrew setup in sync with bootstrap.sh's streamed preflight.
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64) BOOTSTRAP_OS=linux; GO_PLATFORM=linux-amd64; RUST_TARGET=x86_64-unknown-linux-musl ;;
  Darwin/arm64) BOOTSTRAP_OS=darwin; GO_PLATFORM=darwin-arm64; RUST_TARGET=aarch64-apple-darwin ;;
  *) die "unsupported platform $(uname -s)/$(uname -m); supported: linux/amd64 and darwin/arm64 (run natively, not under Rosetta)" ;;
esac
if [ "$BOOTSTRAP_OS" = darwin ]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
  have brew || die "Homebrew is required. Install it from https://brew.sh, then rerun bootstrap (expected /opt/homebrew/bin/brew)."
  [ "$(id -u)" -ne 0 ] || die "run bootstrap as your normal user; Homebrew must not run as root"
  xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools are required: run xcode-select --install, finish installation, then rerun bootstrap."
else
  [ -r /etc/os-release ] && . /etc/os-release
  case ${ID:-} in
    debian|ubuntu) ;;
    *) die "targets Debian or Ubuntu on Linux, found ${PRETTY_NAME:-unknown}" ;;
  esac
fi

cpu_count() {
  if [ "$BOOTSTRAP_OS" = darwin ]; then sysctl -n hw.ncpu; else nproc; fi
}

# Run as root directly, or through sudo for a normal user.
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

# apt_install pkg... : install only the packages that are missing.
apt_install() {
  local p missing=()
  for p in "$@"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' \
      || missing+=("$p")
  done
  [ "${#missing[@]}" -eq 0 ] && return 0
  log "apt install ${missing[*]}"
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    --no-install-recommends "${missing[@]}" >/dev/null
}

# clone_or_update url dir [ref] : shallow clone, or fetch and hard reset if present.
clone_or_update() {
  local url=$1 dir=$2 ref=${3:-}
  if [ -d "$dir/.git" ]; then
    log "update $dir"
    git -C "$dir" fetch --quiet --depth 1 origin ${ref:+"$ref"}
    git -C "$dir" reset --quiet --hard FETCH_HEAD
  else
    log "clone $url -> $dir"
    mkdir -p "$(dirname "$dir")"
    git clone --quiet --depth 1 ${ref:+--branch "$ref"} "$url" "$dir"
  fi
}

# link target name : idempotent symlink. Refuses to clobber a real file.
link() {
  local target=$1 name=$2
  mkdir -p "$(dirname "$name")"
  if [ -L "$name" ] && [ "$(readlink "$name")" = "$target" ]; then return 0; fi
  if [ -e "$name" ] && [ ! -L "$name" ]; then die "$name exists and is not a symlink"; fi
  ln -sfn "$target" "$name"
}

# fetch url dest : download to dest, atomically.
fetch() {
  local url=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  curl -fsSL --retry 3 -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
}
