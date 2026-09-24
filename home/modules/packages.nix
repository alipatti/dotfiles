# packages and fonts. programs with home-manager modules are enabled in
# their own files instead

{ config, pkgs, ... }:
let
  # tectonic has no TEXINPUTS, so always search ../../latex for the classes and
  # packages there. -Z is only accepted by the compile subcommand (or the v1
  # cli, which is compile)
  tectonic = pkgs.writeShellScriptBin "tectonic" ''
    case " $* " in
      *" -X "*) [[ " $* " == *" compile "* ]] && set -- "$@" -Z search-path=${config.lib.dotfiles.root}/latex ;;
      *) set -- "$@" -Z search-path=${config.lib.dotfiles.root}/latex ;;
    esac
    exec ${pkgs.tectonic}/bin/tectonic "$@"
  '';
in
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
