# machine-wide config for the mac. everything here runs as root at
# `darwin-rebuild switch`. per-user files live in ../../home.

{ pkgs, lib, ... }:

{
  imports = [
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = 7;

  # the nix fish doesn't run macos's path_helper, so add brew's bin ourselves.
  # after nix's own paths so nix packages win
  environment.systemPath = lib.mkAfter [ "/opt/homebrew/bin" ];

  # must match the key in flake.nix for `darwin-rebuild --flake ~/.dotfiles`
  networking.hostName = "macbook";
  networking.localHostName = "macbook";
  networking.computerName = "macbook";

  # determinate nix manages the daemon and /etc/nix/nix.conf, not nix-darwin.
  # extra settings go in /etc/nix/nix.custom.conf
  nix.enable = false;

  # user that options like defaults and homebrew apply to
  system.primaryUser = "ali";

  # nix-darwin has to "own" the user to be allowed to set its shell
  users.knownUsers = [ "ali" ];
  users.users.ali = {
    uid = 501;
    home = "/Users/ali";
    shell = pkgs.fish;
  };

  # installs fish, adds it to /etc/shells, and sets up nix paths in /etc/fish
  programs.fish.enable = true;
}
