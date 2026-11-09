# typst, and the package in libraries/typst, imported as @ali/<name>:<version>.
# the working tree is linked live under the version in its typst.toml, and older
# versions are built from the last commit before each bump (see the package's README)

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.lib.dotfiles) root live;
  source = ../../libraries/typst;
  package = (lib.importTOML (source + "/typst.toml")).package;

  # version = last commit of that version, and where the package was then
  releases = {
    "0.1.0" = {
      rev = "7097164507b5d522d64ea6338064e1fec6ef93fb";
      path = "packages/typst/template";
    };
  };

  fetch =
    { rev, path }:
    "${
      builtins.fetchGit {
        url = "file://${root}";
        inherit rev;
      }
    }/${path}";

  packages = pkgs.linkFarm "typst-packages-ali" (
    lib.mapAttrs' (
      version: release: lib.nameValuePair "${package.name}/${version}" (fetch release)
    ) releases
    // {
      "${package.name}/${package.version}" = live source;
    }
  );
in
{
  home.packages = [ pkgs.typst ];

  home.file."Library/Application Support/typst/packages/ali" =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      {
        source = packages;
      };
  xdg.dataFile."typst/packages/ali" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    source = packages;
  };
}
