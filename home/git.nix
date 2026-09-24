{ config, pkgs, ... }:
let
  inherit (config.lib.dotfiles) root;
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Alistair Pattison";
        email = "alistairpattison@gmail.com";
      };

      init.defaultBranch = "main";
      # applies to every repo. replaces per-repo .git/hooks, which i don't use
      core.hooksPath = "${config.xdg.configHome}/git/hooks";
      push = {
        autoSetupRemote = true;
        followTags = true;
      };
      pull.rebase = "merges";
    };

    # written to ~/.config/git/ignore, which git reads by default
    ignores = [
      ".DS_Store"
      "*.local.*"
      "**/.claude/.cc-writes/"
      "**/.claude/settings.local.json"
    ];
  };

  # also registers gh as git's credential helper for github. auth state lives
  # in ~/.config/gh/hosts.yml, written by `gh auth login`
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
      aliases.co = "pr checkout";
    };
  };

  # tag python package version bumps. the script needs python 3.11+, which
  # the system python isn't, so run it with the nix one
  xdg.configFile."git/hooks/post-commit" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec ${pkgs.python3}/bin/python3 ${root}/tools/git_tag_version.py "$@"
    '';
  };
}
