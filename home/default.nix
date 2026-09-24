# per-user config shared across machines. platform-specific bits live in
# ./darwin.nix, and the rest is split by program into the files imported here

{ config, pkgs, lib, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  imports = [
    ./packages.nix
    ./languages.nix
    ./shell.nix
    ./prompt.nix
    ./kitty.nix
    ./git.nix
    ./ssh.nix
    ./agents.nix
    ./papis.nix
    ./rumdl.nix
  ];

  # shared by the modules above: symlink straight into the repo so configs
  # stay editable in place
  lib.dotfiles.link =
    path: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/${path}";

  home.username = "ali";
  home.stateVersion = "26.11";

  # the generated home-manager man page trips a nix warning about missing
  # string context under determinate nix's lazy trees
  manual.manpages.enable = false;

  # sets XDG_{CONFIG,DATA,CACHE,STATE}_HOME and lets modules use xdg.configFile
  xdg.enable = true;

  # exported by the home-manager session vars, which fish sources below.
  # secrets stay in ../secrets.env, sourced via direnv in shell.nix
  home.sessionPath = [ "$HOME/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
  };

  # ~/.config
  xdg.configFile = {
    "nvim".source = link "nvim";
  };

  # ~
  home.file = {
    ".latexmkrc".source = link "latex/.latexmkrc";
  };
}
