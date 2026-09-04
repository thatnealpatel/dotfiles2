#!/usr/bin/env bash
# 05-tailscale: install tailscale from its apt repo; join the tailnet if a key
# was given (bootstrap.sh -ts_authkey KEY, or $TS_AUTHKEY).
#
# On a real host tailscaled runs under systemd as usual. In a container with
# no init and no TUN device it falls back to userspace networking as the
# current user, with a SOCKS5 proxy on localhost:1055 for reaching tailnet
# hosts. That mode is for tests; use an ephemeral key so the node removes
# itself.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
. "$(dirname "$0")/../versions.sh"
log "stage 05-tailscale"

if ! have tailscale; then
  log "install tailscale"
  . /etc/os-release   # ID is debian or ubuntu; tailscale mirrors that layout
  as_root install -d -m 0755 /usr/share/keyrings
  curl -fsSL "https://pkgs.tailscale.com/stable/$ID/$VERSION_CODENAME.noarmor.gpg" \
    | as_root tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL "https://pkgs.tailscale.com/stable/$ID/$VERSION_CODENAME.tailscale-keyring.list" \
    | as_root tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  apt_install tailscale
fi

if tailscale status >/dev/null 2>&1; then
  log "already on the tailnet: $(tailscale ip -4 | head -1)"
  exit 0
fi

if [ -z "${TS_AUTHKEY:-}" ]; then
  log "no TS_AUTHKEY; installed but not joined. later: sudo tailscale up"
  exit 0
fi

if [ -d /run/systemd/system ]; then
  as_root systemctl enable --now tailscaled >/dev/null
  as_root tailscale up --auth-key="$TS_AUTHKEY"
  log "tailscale: $(tailscale ip -4)"
else
  warn "no systemd; tailscaled in userspace mode, SOCKS5 on localhost:1055"
  state="$HOME/.local/state/tailscale"
  mkdir -p "$state"
  sock="$state/tailscaled.sock"
  if ! tailscale --socket="$sock" status >/dev/null 2>&1; then
    nohup tailscaled --tun=userspace-networking --statedir="$state" --socket="$sock" \
      --socks5-server=localhost:1055 >"$state/tailscaled.log" 2>&1 &
    for _ in $(seq 50); do [ -S "$sock" ] && break; sleep 0.2; done
  fi
  tailscale --socket="$sock" up --auth-key="$TS_AUTHKEY"
  log "tailscale: $(tailscale --socket="$sock" ip -4)"
  # make the plain `tailscale` command and curl find it in interactive shells
  local_zsh="$HOME/.config/zsh/local.zsh"
  [ -f "$local_zsh" ] || cp "$HOME/.config/zsh/local.zsh.example" "$local_zsh"
  grep -q 'tailscale --socket=' "$local_zsh" || cat >>"$local_zsh" <<EOF

# tailscale in userspace mode (container test)
alias tailscale='tailscale --socket=$sock'
export ALL_PROXY=socks5h://localhost:1055   # h: resolve MagicDNS names via the proxy
EOF
fi
