# python: uv and ipython. the ipython config is in ./ipython

{ config, pkgs, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  home.packages = [ pkgs.uv ];

  home.sessionVariables.POLARS_ENGINE_AFFINITY = "streaming";

  # link only the config pieces so ipython's runtime files (history, logs,
  # pid) stay out of the repo
  home.file = {
    ".ipython/profile_default/ipython_config.py".source = link ./ipython/ipython_config.py;
    ".ipython/profile_default/startup".source = link ./ipython/startup;
  };
}
