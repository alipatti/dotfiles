# per-user config shared across machines. platform-specific bits live in
# ./profiles, and shared content is split by program in ./programs

{ config, lib, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  # shared by the modules above. both take a path literal (e.g. ./functions).
  # `live` turns it into the same path in the working tree, so programs read
  # the file as edited rather than a copy in the store, and `link` symlinks to
  # it so configs stay editable in place
  lib.dotfiles = {
    root = "${config.home.homeDirectory}/.dotfiles";
    live =
      path:
      assert lib.assertMsg (builtins.isPath path && builtins.pathExists path)
        "lib.dotfiles.live: ${toString path} is not an existing path";
      config.lib.dotfiles.root + lib.removePrefix (toString ../.) (toString path);
    link = path: config.lib.file.mkOutOfStoreSymlink (config.lib.dotfiles.live path);
  };

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
    DOTFILES = config.lib.dotfiles.root;
  };

  # ~/.config
  xdg.configFile = {
    "nvim".source = link ../nvim;
  };
}
