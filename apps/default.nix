# software written here. the flake exposes these as `packages` and through
# `overlays.default`, so modules install them as pkgs.<name>

pkgs:
let
  # installs a script as the command `name`. the python ones run through the
  # `uv run --script` in their shebang, which installs their pep 723 deps
  command =
    name: script:
    pkgs.runCommand name { meta.mainProgram = name; } ''
      install -Dm755 ${script} $out/bin/${name}
    '';
in
{
  pdf2md = command "pdf2md" ./pdf2md/pdf2md.py;

  # princeton's student print queues. mac only: it uses the keychain and ipconfig
  pawprint = command "pawprint" ./pawprint/pawprint.py;

  # the viewer command. on macos it opens viewer.app, which
  # home/programs/viewer.nix builds
  viewer = command "viewer" ./viewer/viewer.sh;
}
