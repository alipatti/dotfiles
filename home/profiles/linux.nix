# per-user config that only makes sense on linux (gnome on fridge)

{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    firefox
    slack
    spotify
    prismlauncher
    trashy
    wl-clipboard # clipboard for the tailscale systray
    gcc # rustup toolchains and uv sdists need a c compiler
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };

  services.tailscale-systray.enable = true;

  dconf.settings = {
    "org/gnome/desktop/input-sources".xkb-options = [ "caps:escape" ];
    "org/gnome/shell".enabled-extensions = [ "appindicatorsupport@rgcjonas.gmail.com" ];
  };
}
