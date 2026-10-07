# home-manager module for `pawprint`, princeton's student print queues. mac
# only: it converts files with cupsfilter and the PPDs from oit's installer
# (PawPrint_Combined_Installer.app)

{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ../python-tool.nix { } "pawprint" ./pawprint.py) ];
}
