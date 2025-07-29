#! /usr/bin/env bash

echo "Installing prebuilt Linux binaries for Fish..."

go_back_to=$(pwd)
cd /tmp/fish-installation-o1roasdf809as8dfmasdkjf

# fetch binary
wget https://github.com/fish-shell/fish-shell/releases/download/4.0.0/fish-static-aarch64-4.0.0.tar.xz

# extract contents
tar -xf fish-static-* && rm fish-static-*

# install into path
mv * ~/.local/bin/
