# per-user config shared across machines. platform-specific bits live in
# this folder, and shared content is split by program in ./modules

{ config, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  # tools that don't fit a module in ./modules, on every machine
  imports = [ ../tools/pdf2md ];

  # shared by the modules above. `link` symlinks straight into the repo so
  # configs stay editable in place
  lib.dotfiles.root = "${config.home.homeDirectory}/.dotfiles";
  lib.dotfiles.link = path: config.lib.file.mkOutOfStoreSymlink "${config.lib.dotfiles.root}/${path}";

  home.stateVersion = "26.11";

  # the generated home-manager man page trips a nix warning about missing
  # string context under determinate nix's lazy trees
  manual.manpages.enable = false;

  # sets XDG_{CONFIG,DATA,CACHE,STATE}_HOME and lets modules use xdg.configFile
  xdg.enable = true;

  xdg.localBinInPath = true;
  # `cargo install` binaries; rustup itself comes from nix
  home.sessionPath = [ "$HOME/.cargo/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
  };

  # ~/.config
  xdg.configFile = {
    "nvim".source = link "nvim";
  };
}
