# home-manager module for `pawprint`, princeton's student print queues. mac
# only: the queues come from oit's installer (PawPrint_Combined_Installer.app)

{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ../python-tool.nix { } "pawprint" ./pawprint.py) ];
}
