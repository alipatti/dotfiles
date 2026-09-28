# per-user config for hpc clusters without root

{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # cherry-pick necessary parts
    ./modules/agents.nix
    ./modules/git.nix
    ./modules/languages.nix
    ./modules/packages.nix
    ./modules/prompt.nix
    ./modules/rumdl.nix
    ./modules/shell.nix
    ./modules/ssh.nix
  ];

  # the netid differs between clusters, so this needs --impure
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # xdg paths, locale and terminfo for nix programs on a non-nixos distro
  targets.genericLinux.enable = true;

  nix.package = pkgs.nix;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # collect garbage on every switch. nix.gc.automatic needs a systemd user
  # timer, which login nodes don't run. -d also drops old generations, so
  # there is no rollback, but the store stays under quota
  home.activation.gc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${config.nix.package}/bin/nix-collect-garbage -d
  '';
}
