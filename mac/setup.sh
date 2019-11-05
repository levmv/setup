#!/usr/bin/env bash

# Ask for the root password upfront
sudo -v

xcode-select --install

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"


brew install coreutils bash bash-completion@2 \
              git tmux vim \
              curl wget \
              httpie nmap socat \
              go python3 \
              unrar \
              yarn \
              sloccount

BREW_PREFIX=$(brew --prefix)

echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
chsh -s ${BREW_PREFIX}/bin/bash

brew tap homebrew/cask-fonts

brew cask install google-chrome \
                      firefox \
                      iterm2 \
                      sequel-pro \
                      the-unarchiver

npm install -g how-2
