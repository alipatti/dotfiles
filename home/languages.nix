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

  home.sessionVariables.POLARS_ENGINE_AFFINITY = "streaming";

  home.file = {
    # python
    # link only the config pieces so ipython's runtime files (history,
    # logs, pid) stay out of the repo
    ".ipython/profile_default/ipython_config.py".source = link "ipython/ipython_config.py";
    ".ipython/profile_default/startup".source = link "ipython/startup";

    # r
    ".Rprofile".text = ''
      options(
        readr.show_col_types = FALSE,
        repos = c(CRAN = "https://cloud.r-project.org/"),
        max.print = 500
      )
    '';
  };
}
