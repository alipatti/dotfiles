{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    neovim
    tree-sitter

    # language servers, enabled in ./plugin/lsp.lua. ty and ruff's
    # servers run through uvx
    lua-language-server
    yaml-language-server
    taplo
    vscode-langservers-extracted # json
    fish-lsp
    svelte-language-server
    tailwindcss-language-server
    tinymist
    nixd # nix
    nixfmt # used by nixd for formatting
    texlab
  ];

  home.sessionVariables.EDITOR = "nvim";

  xdg.configFile."nvim".source = config.lib.dotfiles.link ./.;
}
