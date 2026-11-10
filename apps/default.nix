# software written here. the flake exposes these as `packages` and through
# `overlays.default`, so modules install them as pkgs.<name>

pkgs:
let
  pythonTool = pkgs.callPackage ./python-tool.nix { };
in
{
  pdf2md = pythonTool "pdf2md" ./pdf2md/pdf2md.py;

  # princeton's student print queues. mac only: it uses the keychain and ipconfig
  pawprint = pythonTool "pawprint" ./pawprint/pawprint.py;

  # the viewer command. on macos it opens viewer.app, which
  # config/viewer.nix builds
  viewer = pkgs.runCommand "viewer" { meta.mainProgram = "viewer"; } ''
    install -Dm755 ${./viewer/viewer.sh} $out/bin/viewer
  '';
}
