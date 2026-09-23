# packages and fonts. programs with home-manager modules are enabled in
# their own files instead

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # documents
    tectonic
    typst
    pandoc
    papis

    # git
    git-crypt # encryption

    # editor
    neovim
    tree-sitter

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

    # fonts. home-manager installs these in ~/Library/Fonts on macos and
    # through fontconfig on linux
    nerd-fonts.cousine
    lmodern # latin modern
  ];

  fonts.fontconfig.enable = true;
}
