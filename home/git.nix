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
      push = {
        autoSetupRemote = true;
        followTags = true;
      };
      pull.rebase = "merges";
    };

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

  # sets core.hooksPath, so these apply to every repo and per-repo .git/hooks
  # (and `pre-commit install`) stop working. tags python package version
  # bumps; the script needs python 3.11+, which the system python isn't
  programs.git.hooks.post-commit = pkgs.writeShellScript "post-commit" ''
    exec ${pkgs.python3}/bin/python3 ${root}/tools/git_tag_version.py "$@"
  '';
}
