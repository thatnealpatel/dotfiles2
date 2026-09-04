#!/usr/bin/env bash
# 15-jj: jujutsu from the pinned release tarball into ~/.local/bin, plus its
# zsh completion, plus watchman so jj snapshots the working copy on every file
# change. Config is tracked at ~/.config/jj/config.toml.
#
# watchman's prebuilt binary is linked against absolute /usr/local/lib paths,
# so it is installed exactly where its instructions say, with sudo.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 15-jj"

jj="$HOME/.local/bin/jj"
want=${JJ_VERSION#v}
# --version prints "jj 0.45.1-<commit>"; compare the part before the dash
if [ ! -x "$jj" ] || [ "$("$jj" --version | awk '{print $2}' | cut -d- -f1)" != "$want" ]; then
  log "jj $JJ_VERSION"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL --retry 3 \
    "https://github.com/jj-vcs/jj/releases/download/$JJ_VERSION/jj-$JJ_VERSION-x86_64-unknown-linux-musl.tar.gz" \
    | tar -C "$HOME/.local/bin" -xzf - ./jj
  chmod 755 "$jj"
fi

# completion, regenerated each run so it matches the binary
mkdir -p "$HOME/.local/share/zsh/completions"
"$jj" util completion zsh >"$HOME/.local/share/zsh/completions/_jj"

# watchman. --version prints a build stamp like 20260727.012849.0, so the
# installed check compares the date part of the tag (v2026.07.27.00 -> 20260727).
wm=/usr/local/bin/watchman
wm_date=$(printf '%s' "${WATCHMAN_VERSION#v}" | cut -d. -f1-3 | tr -d .)
if [ ! -x "$wm" ] || ! "$wm" --version 2>/dev/null | grep -q "^$wm_date"; then
  log "watchman $WATCHMAN_VERSION"
  tmp=$(mktemp -d)
  curl -fsSL --retry 3 -o "$tmp/watchman.zip" \
    "https://github.com/facebook/watchman/releases/download/$WATCHMAN_VERSION/watchman-$WATCHMAN_VERSION-linux.zip"
  unzip -q "$tmp/watchman.zip" -d "$tmp"
  as_root install -d -m 755 /usr/local/bin /usr/local/lib
  as_root install -m 755 "$tmp"/watchman-*/bin/* /usr/local/bin/
  as_root install -m 644 "$tmp"/watchman-*/lib/* /usr/local/lib/
  rm -rf "$tmp"
fi
# per-user state dirs live under here; watchman requires sticky world-writable
as_root install -d -m 2777 /usr/local/var/run/watchman

# watchman sets one inotify watch per file; the kernel default runs out on a
# big tree. Persist a higher limit and apply it now where the kernel allows
# (not in a container).
sysctl_conf=/etc/sysctl.d/90-inotify.conf
if [ ! -f "$sysctl_conf" ]; then
  printf 'fs.inotify.max_user_watches = 1048576\nfs.inotify.max_user_instances = 1024\n' \
    | as_root tee "$sysctl_conf" >/dev/null
  as_root sysctl -q -p "$sysctl_conf" 2>/dev/null || warn "inotify limits saved; apply on next boot"
fi

log "jj -> $("$jj" --version); watchman $("$wm" --version)"
