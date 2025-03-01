### Setup

```bash
% apt install zsh
# don't blindly trust:
% sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
% rm ~/.zshrc
% mkdir $HOME/.dotfiles
% git clone --bare git@github.com:thatnealpatel/dotfiles2.git $HOME/.dotfiles
% /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME checkout
% /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME config status.showUntrackedFiles no
% cp $HOME/.config/papercolor.zsh-theme $HOME/.oh-my-zsh/custom/themes/

# too lazy to do proper git submodule stuff
% cd .oh-my-zsh/custom/plugins/
% git clone https://github.com/zsh-users/zsh-autosuggestions.git
% git clone https://github.com/zsh-users/zsh-completions.git
% git clone https://github.com/zsh-users/zsh-syntax-highlighting.git

# done
% echo $PATH > ~/.LOCALPATH
% source .zshrc

# other https://go.dev/dl/
% cd ~/tmp
% wget CHOOSE_GO_VERSION
% rm -rf /usr/local/go && tar -C /usr/local -xzf go1.24.0.linux-amd64.tar.gz
% echo ":/usr/local/go/bin" >> ~/.LOCALPATH
```
