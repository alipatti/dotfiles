#! /usr/bin/env bash

if [[ command -v fish ]]
then
    echo "Fish not found. Installing Linux binaries..."

    go_back_to=$(pwd)
    cd /tmp/fish-installation-o1roasdf809as8dfmasdkjf

    # fetch binary
    # NOTE: update this with new versions as needed
    wget https://github.com/fish-shell/fish-shell/releases/download/4.0.0/fish-static-aarch64-4.0.0.tar.xz

    # extract contents and move into PATH
    tar -xf fish-static-* && rm fish-static-* && mv * ~/.local/bin/

    cd go_back_to
fi

# set fish as default shell
if [[ $SHELL != *"fish"* ]]
then
    echo "Login shell is not fish. Setting now."
    FISH=$(readlink -f $(which fish))
    sudo add-shell $FISH && chsh -s $FISH && echo "Set shell to $FISH"
fi
