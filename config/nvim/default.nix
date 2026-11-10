{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    neovim
    tree-sitter

    # language servers, enabled in ./plugin/lsp.lua. ty and ruff's
    # servers run through uvx, and the web ones are in ../web.nix
    lua-language-server
    yaml-language-server
    taplo
    vscode-langservers-extracted # json
    fish-lsp
    tinymist
    nixd # nix
    nixfmt # used by nixd for formatting
    texlab
  ];

  home.sessionVariables.EDITOR = "nvim";

  xdg.configFile."nvim".source = config.lib.dotfiles.link ./.;
}
