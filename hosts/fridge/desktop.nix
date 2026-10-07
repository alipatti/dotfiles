# desktop sessions, picked from the gdm login screen (gear icon)

{ pkgs, ... }:

{
  # gdm/gnome
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  # the niri module makes itself the default; keep gnome
  services.displayManager.defaultSession = "gnome";

  programs.hyprland.enable = true;
  programs.niri.enable = true;

  # swaylock can't unlock without a pam entry
  security.pam.services.swaylock = { };

  environment.systemPackages = with pkgs; [
    nautilus
    gnomeExtensions.appindicator # systray support for gnome

    # what the default hyprland config binds (kitty comes from home-manager)
    hyprlauncher # super+r

    # what the default niri config binds
    fuzzel # mod+d
    waybar # started at login
    swaylock # super+alt+l
    xwayland-satellite # x11 apps (steam, etc.)

    mako # notifications, for both
  ];
}
