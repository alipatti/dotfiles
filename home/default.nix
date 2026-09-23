# per-user config shared across machines: packages, symlinks into this repo,
# and small setup steps. platform-specific bits live in ./darwin.nix.

{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # symlink straight into the repo so configs stay editable in place
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.username = "ali";
  home.stateVersion = "26.11";

  home.packages = with pkgs; [
    # languages
    uv # python
    nodejs # js
    pnpm # js
    rustup # rust

    # tex
    tectonic

    # git
    git
    git-crypt # encryption
    gh # github

    # editor
    neovim
    tree-sitter

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
  ];

  xdg.configFile = {
    fish.source = link "fish";
    kitty.source = link "kitty";
    nvim.source = link "nvim";
    gh.source = link "github";
    "starship.toml".source = link "starship/starship.toml";
    rumdl.source = link "rumdl";
  };

  home.file = {
    ".gitignore".source = link "git/ignore";
    ".gitconfig".source = link "git/config";
    ".git/templates".source = link "git/templates";

    ".rprofile".source = link "r/.rprofile";
    ".lintr".source = link "r/.lintr";
    ".radian_profile".source = link "r/.radian_profile";

    ".claude".source = link "claude";
    ".codex/AGENTS.md".source = link "claude/CLAUDE.md";
    ".codex/skills".source = link "skills";

    ".ipython".source = link "ipython";
    ".latexmkrc".source = link "latex/.latexmkrc";
    ".ssh".source = link "ssh";

    ".hushlogin".text = ""; # hide fish "last login" message
  };
}
