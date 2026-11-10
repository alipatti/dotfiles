# programs with home-manager modules are enabled in their own files instead

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # git
    git-crypt # encryption

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
    pdf2md # apps/pdf2md
    llama-cpp # llama-server, used by pdf2md's ocr models

    # fonts. home-manager installs these in ~/Library/Fonts on macos and
    # through fontconfig on linux. the terminal font is set in ./kitty
    lmodern # latin modern
    newcomputermodern # typst's default text font
  ];
}
