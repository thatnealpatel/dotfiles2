# shellcheck shell=bash
# Version pins. Bump here, then re-run the matching stage:
#   ~/.bootstrap/bootstrap.sh 50-neovim

NVIM_VERSION=v0.12.5           # https://github.com/neovim/neovim/releases
GO_BOOTSTRAP_VERSION=go1.27.1  # https://go.dev/dl ; only used to build tip
ZOXIDE_VERSION=v0.10.0         # https://github.com/ajeetdsouza/zoxide/releases

# Optional tool managers, 0 or 1. opam and elan are always installed.
INSTALL_GCLOUD=0
INSTALL_NVM=0
