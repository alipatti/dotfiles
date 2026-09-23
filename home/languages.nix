# language toolchains and their config

{ config, pkgs, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  home.packages = with pkgs; [
    uv # python
    nodejs # js
    pnpm # js
    rustup # rust
  ];

  home.sessionVariables = {
    N_PREFIX = "$HOME/.n";
    POLARS_ENGINE_AFFINITY = "streaming";
  };

  home.file = {
    # python
    ".ipython".source = link "ipython";

    # r
    ".rprofile".source = link "r/.rprofile";
    ".lintr".source = link "r/.lintr";
    ".radian_profile".source = link "r/.radian_profile";
  };
}
