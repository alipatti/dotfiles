# home-manager module for `pawprint`, princeton's student print queues. mac
# only: it uses the keychain and ipconfig

{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ../python-tool.nix { } "pawprint" ./pawprint.py) ];
}
