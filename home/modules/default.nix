{ lib, ... }:
{
  imports = lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (
      name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    ))
    builtins.attrNames
    (map (name: ./. + "/${name}"))
  ];
}
