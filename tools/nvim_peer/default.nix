# home-manager module for `_nvim_peer`, which lets agents see and move the
# cursor of the nvim in another kitty window. underscored to stay out of the
# way when completing `nvim`

{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ../python-tool.nix { } "_nvim_peer" ./nvim_peer.py) ];
}
