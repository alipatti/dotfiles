# imports every module here: x.nix, or x/default.nix for a program whose
# config files and scripts sit beside its module

{ lib, ... }:
{
  imports = lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (
      name: type:
      if type == "directory" then
        builtins.pathExists (./. + "/${name}/default.nix")
      else
        type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    ))
    builtins.attrNames
    (map (name: ./. + "/${name}"))
  ];
}
