# language toolchains and their config. python and js have their own modules
# in ./python and ./web.nix

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup # rust; also provides rust-analyzer via `rustup component add rust-analyzer`
  ];

  # r
  home.file.".Rprofile".text = ''
    options(
      readr.show_col_types = FALSE,
      repos = c(CRAN = "https://cloud.r-project.org/"),
      max.print = 500
    )
  '';
}
