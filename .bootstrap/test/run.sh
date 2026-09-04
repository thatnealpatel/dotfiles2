#!/usr/bin/env bash
# Run bootstrap end to end in a throwaway Debian 13 container.
#
#   .bootstrap/test/run.sh                 all stages, then checks
#   .bootstrap/test/run.sh 50-neovim       named stages only
#   .bootstrap/test/run.sh -i              ...then drop into zsh inside the container
#   .bootstrap/test/run.sh -i -ts_authkey tskey-auth-...
#                                          ...and join the tailnet (use an ephemeral key)
#                                          (TS_AUTHKEY in the environment also works)
#
# The working tree of this clone (tracked and untracked, uncommitted included)
# is snapshotted into a throwaway repo inside the container and bootstrap
# clones from that. Nothing in this clone is committed, pushed, or modified.
#
# ~/.cache, ~/w and ~/go in the container are named docker volumes so the
# neovim build, the Go tip clone and build, and the module cache carry over
# between runs. Everything else is fresh each run. Reset with:
#   docker volume rm dotfiles2-test-cache dotfiles2-test-w dotfiles2-test-go
set -euo pipefail

interactive=0
stages=()
while [ $# -gt 0 ]; do
  case $1 in
    -i)            interactive=1; shift ;;
    -ts_authkey)   TS_AUTHKEY=$2; shift 2 ;;
    -ts_authkey=*) TS_AUTHKEY=${1#*=}; shift ;;
    -h|--help)     sed -n '2,17p' "$0"; exit 0 ;;
    -*)            echo "run.sh: unknown flag $1" >&2; exit 2 ;;
    *)             stages+=("$1"); shift ;;
  esac
done

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
image=dotfiles2-test

docker build -q -t "$image" "$here" >/dev/null

tty=()
[ -t 0 ] && tty=(-it)
if [ "$interactive" = 1 ] && [ ${#tty[@]} -eq 0 ]; then
  echo "run.sh: -i needs a terminal" >&2; exit 1
fi

docker run --rm "${tty[@]}" \
  -v "$root:/src:ro" \
  -v dotfiles2-test-cache:/home/neal/.cache \
  -v dotfiles2-test-w:/home/neal/w \
  -v dotfiles2-test-go:/home/neal/go \
  -e STAGES="${stages[*]:-}" \
  -e TS_AUTHKEY="${TS_AUTHKEY:-}" \
  -e SHELL_AFTER="$interactive" \
  "$image" bash /src/.bootstrap/test/inside.sh
