#!/usr/bin/env bash
# Runs inside the test container. Invoked by run.sh, not directly.
# Snapshots the read-only mount at /src into a throwaway repo and bootstraps from it.
set -euo pipefail

git config --global --add safe.directory /src
mkdir -p /tmp/src
# ls-files -c includes files deleted in the working tree; keep only what exists.
git -C /src ls-files -co --exclude-standard -z \
  | while IFS= read -r -d '' f; do [ -e "/src/$f" ] && printf '%s\0' "$f"; done \
  | tar -C /src --null -T - -cf - | tar -C /tmp/src -xf -
git -C /tmp/src init -q -b main
git -C /tmp/src -c user.name=test -c user.email=test@localhost add -A
git -C /tmp/src -c user.name=test -c user.email=test@localhost commit -q -m snapshot

export DOTFILES_REPO=/tmp/src DOTFILES_REF=main
# shellcheck disable=SC2086
bash /tmp/src/.bootstrap/bootstrap.sh ${STAGES:-}

echo
echo "--- tracked files in \$HOME:"
git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" ls-files

echo
bash /src/.bootstrap/test/check.sh
rc=$?

if [ "${SHELL_AFTER:-0}" = 1 ]; then
  echo
  echo "--- interactive shell in the container. exit to tear it down."
  # a real Go repo to try the editor on
  [ -d "$HOME/p/mono/.git" ] || git clone --quiet https://github.com/thatnealpatel/mono "$HOME/p/mono"
  cd "$HOME/p/mono" && exec zsh -l
fi
exit "$rc"
