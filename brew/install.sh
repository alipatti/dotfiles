#!/usr/bin/env bash

if ! command -v brew &>/dev/null; then
    echo "Brew not found. Installing it..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Brew installation found. Continuing..."
fi
