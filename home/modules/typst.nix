# local typst packages, imported as @ali/template:<version>.
# the working tree is linked live under the version in its typst.toml, and older
# versions are built from the last commit before each bump (see the package's README)

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.lib.dotfiles) root;
  template = "packages/typst/template";

  # version = last commit of that version
  releases = {
  };

  current = (lib.importTOML ../../${template}/typst.toml).package.version;
  fetch = rev: "${builtins.fetchGit { url = "file://${root}"; inherit rev; }}/${template}";

  packages = pkgs.linkFarm "typst-packages-ali" (
    lib.mapAttrs' (version: rev: lib.nameValuePair "template/${version}" (fetch rev)) releases
    // { "template/${current}" = "${root}/${template}"; }
  );
in
{
  home.file."Library/Application Support/typst/packages/ali" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = packages;
  };
  xdg.dataFile."typst/packages/ali" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux { source = packages; };
}
