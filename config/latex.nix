{ config, pkgs, ... }:
let
  # tectonic has no TEXINPUTS, so always search libraries/latex for the classes and
  # packages there. search paths aren't recursive, so each subdirectory is listed.
  # -Z is only accepted by the compile subcommand (or the v1 cli, which is compile)
  latex = config.lib.dotfiles.live ../libraries/latex;
  tectonic = pkgs.writeShellScriptBin "tectonic" ''
    search="-Z search-path=${latex} -Z search-path=${latex}/classes -Z search-path=${latex}/resources"
    case " $* " in
      *" -X "*) [[ " $* " == *" compile "* ]] && set -- "$@" $search ;;
      *) set -- "$@" $search ;;
    esac
    exec ${pkgs.tectonic}/bin/tectonic "$@"
  '';
in
{
  home.packages = [ tectonic ];
}
