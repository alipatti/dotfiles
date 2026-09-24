# packages and fonts. programs with home-manager modules are enabled in
# their own files instead

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # documents
    tectonic
    typst
    pandoc

    # git
    git-crypt # encryption

    # editor
    neovim
    tree-sitter

    # language servers, enabled in nvim/plugin/lsp.lua
    pyright
    ruff
    lua-language-server
    yaml-language-server
    taplo
    vscode-langservers-extracted # json
    fish-lsp
    svelte-language-server
    tailwindcss-language-server
    tinymist
    nixd # nix
    rust-analyzer
    texlab

    # command line tools
    eza # better ls
    fd # better find
    ripgrep # better grep
    ripgrep-all # search pdfs & more
    jq # json parser
    scc # line counter
    watchexec # run command on file change
    poppler-utils # pdf tools
    just
    wget
    file

    # fonts. home-manager installs these in ~/Library/Fonts on macos and
    # through fontconfig on linux. the terminal font is set in kitty.nix
    lmodern # latin modern
  ];
}
