# dotfiles2

Debian 13 x86_64. One command on a fresh host with sudo:

```sh
curl -fsSL https://raw.githubusercontent.com/thatnealpatel/dotfiles2/main/.bootstrap/bootstrap.sh | bash
exec zsh
```

That clones this repo as a bare repo at `~/.dotfiles` with `$HOME` as the
work tree, checks it out, installs packages, and runs every stage under
`.bootstrap/stages` in order. It is safe to run again.

## Daily use

| what                       | where                                   |
|----------------------------|-----------------------------------------|
| repo status, commit        | `dgs`, `dgc` (aliases for the bare repo) |
| re-run one stage           | `~/.bootstrap/bootstrap.sh 50-neovim`   |
| bump a version             | `.bootstrap/versions.sh`, then re-run the stage |
| add a package              | `.bootstrap/apt-packages.txt`           |
| add a Go tool              | `.bootstrap/go-tools.txt`               |
| host-specific shell config | `~/.config/zsh/local.zsh` (untracked)   |
| host-specific nvim config  | `~/.config/nvim/lua/local.lua` (untracked) |
| test in a container        | `.bootstrap/test/run.sh`                |

## Home layout

Always created by bootstrap:

```
~/d   downloads and other large things that should persist
~/p   personal; all code lives here
~/w   work
~/t   temporary, but survives reboots
~/s   security
```

## Repo layout

```
.bootstrap/     bootstrap.sh, lib.sh, versions.sh, package lists, stages/, test/
.config/zsh/    shell config, one file per purpose (ZDOTDIR)
.config/tmux/   tmux config
.config/nvim/   neovim config
```

Anything non-portable lives in `local.zsh`, never here.
