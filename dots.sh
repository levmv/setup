#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
echo "";
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" \
        --exclude "README.md" --exclude "LICENSE" -avh --no-perms ./dotfiles/ ~;
fi;
