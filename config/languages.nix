# language toolchains and their config. python has its own module in ./python

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs # js
    pnpm # js
    R # r
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
