#!/usr/bin/env bash

echo "The following packages are installed but are not in your Brewfile."
echo
echo "$(brew bundle cleanup --global | sed '1d;$d' | pr -2t)"
echo
echo "If you would like them to persist, add them to $(pwd | sed "s;$HOME;~;")/brew/Brewfile"
echo "If you would like to remove them, run 'brew bundle cleanup --global --force to remove them all'"
