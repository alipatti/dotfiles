# per-user config shared across machines: packages, symlinks into this repo,
# and small setup steps. platform-specific bits live in ./darwin.nix.

{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # symlink straight into the repo so configs stay editable in place
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  links = builtins.fromTOML (builtins.readFile ../links.toml);
in
{
  home.username = "ali";
  home.stateVersion = "26.11";

  # the generated home-manager man page trips a nix warning about missing
  # string context under determinate nix's lazy trees
  manual.manpages.enable = false;

  home.packages = with pkgs; [
    # languages
    uv # python
    nodejs # js
    pnpm # js
    rustup # rust

    # documents
    tectonic
    typst
    pandoc
    papis

    # git
    git
    git-crypt # encryption
    gh # github

    # editor
    neovim
    tree-sitter

    # ai
    claude-code

    # command line tools
    zoxide # cd
    starship # prompt
    eza # better ls
    fd # better find
    ripgrep # better grep
    ripgrep-all # search pdfs & more
    bat # better cat
    jq # json parser
    scc # line counter
    watchexec # run command on file change
    poppler-utils # pdf tools
    fzf
    just
    wget

    # fonts. home-manager installs these in ~/Library/Fonts on macos and
    # through fontconfig on linux
    nerd-fonts.cousine
    lmodern # latin modern
  ];

  fonts.fontconfig.enable = true;

  home.file = {
    ".hushlogin".text = ""; # hide fish "last login" message
  }
  # see ../links.toml; the darwin section is handled in ./darwin.nix
  // lib.mapAttrs' (
    target: source: lib.nameValuePair (lib.removePrefix "~/" target) { source = link source; }
  ) (removeAttrs links [ "darwin" ]);
}
