# fish and the tools wired into its prompt

{ config, lib, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  # home-manager generates ~/.config/fish/config.fish. functions and
  # completions are symlinked from ../fish below
  programs.fish = {
    enable = true;

    shellAbbrs = {
      # git
      g = "git";
      gs = "git status";
      gd = "git diff";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gcm = "git commit -m";
      gcam = "git commit -am";
      gcanea = "git commit -a --no-edit --amend";
      gp = "git push";
      gl = "git log";
      gladog = "git log --all --decorate --oneline --graph";
      gb = "git branch";

      # other
      vim = "nvim";
      ipy = "ipython";
      npm = "pnpm";
    };

    # runs after the starship/zoxide/fzf integrations
    interactiveShellInit = lib.mkAfter ''
      # claude desktop's terminal panel does not answer fish's terminal queries,
      # which makes fish stall 10s at startup and print a warning. fish only
      # reads fish_features at startup, so export the flag and re-exec once.
      if test "$TERM_PROGRAM" = claude-desktop; and not contains no-query-term $fish_features
          set -gx fish_features $fish_features no-query-term
          if status is-login
              exec fish -l
          else
              exec fish
          end
      end

      # rust
      test -f "$HOME/.cargo/env.fish" && source "$HOME/.cargo/env.fish"

      # bat as the man pager
      set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

      # nixos
      if command -q nix-your-shell
          nix-your-shell fish | source
      end

      if command -q tinymist
          tinymist completion | source
      end

      # automatic venv activation
      activate_venv --quiet

      # replaces the ctrl-r binding from fzf's integration above
      bind \cr search_history

      load_dotenv ${config.home.homeDirectory}/.dotfiles/env/*
    '';
  };

  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    defaultOptions = [
      "--border"
      "--height 40%"
      "--layout=reverse"
      "--info=right"
      "--padding=1"
      "--margin=1"
      "--prompt='❯ '"
      "--marker='✔ '"
      "--pointer=' '"
      "--color=16"
      "--color=bg+:-1"
    ];
  };
  programs.bat = {
    enable = true;
    config.theme = "Coldark-Dark";
  };

  xdg.configFile = {
    "fish/functions".source = link "fish/functions";
    "fish/completions".source = link "fish/completions";
  };

  home.file.".hushlogin".text = ""; # hide fish "last login" message
}
