# packages and fonts. programs with home-manager modules are enabled in
# their own files instead

{ config, pkgs, ... }:
let
  # tectonic has no TEXINPUTS, so always search packages/latex for the classes and
  # packages there. search paths aren't recursive, so each subdirectory is listed.
  # -Z is only accepted by the compile subcommand (or the v1 cli, which is compile)
  latex = config.lib.dotfiles.live ../../packages/latex;
  tectonic = pkgs.writeShellScriptBin "tectonic" ''
    search="-Z search-path=${latex} -Z search-path=${latex}/classes -Z search-path=${latex}/resources"
    case " $* " in
      *" -X "*) [[ " $* " == *" compile "* ]] && set -- "$@" $search ;;
      *) set -- "$@" $search ;;
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

    # language servers, enabled in nvim/plugin/lsp.lua. ty and ruff's servers
    # run through uvx; ruff stays here for rumdl's code-block formatting
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
    nixfmt # used by nixd for formatting
    texlab

    # command line tools
    coreutils # gnu versions, plus timeout, tac, shuf, etc. that macos lacks
    gnused # gnu sed, so `sed -i` matches linux
    eza # better ls
    fd # better find
    ripgrep # better grep
    ripgrep-all # search pdfs & more
    jq # json parser
    tokei # line counter
    watchexec # run command on file change
    poppler-utils # pdf tools
    just
    wget
    file
    xz
    zstd
    p7zip # 7z

    # fonts. home-manager installs these in ~/Library/Fonts on macos and
    # through fontconfig on linux. the terminal font is set in kitty.nix
    lmodern # latin modern
    newcomputermodern # typst's default text font
  ];
}
