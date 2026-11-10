# builds a command from a cyclopts app: either a script with a pep 723 header
# or a uv project directory with the command in `[project.scripts]`. uv
# installs the dependencies on first run, so nix never sees them. the app must
# have a `--completions` command that prints its fish completions, which fish
# runs the first time it completes the command in a session, silenced so
# uv reinstalling the project after an update doesn't print over the prompt
#
#   pkgs.callPackage ./python-tool.nix { } "pawprint" ./pawprint/pawprint.py
#   pkgs.callPackage ./python-tool.nix { } "pdf2md" ./pdf2md

{ lib, pkgs }:
name: source:
let
  uv = lib.getExe pkgs.uv;

  run =
    if lib.pathIsDirectory source then
      ''
        # the store is read-only, so the environment lives in the cache
        export UV_PROJECT_ENVIRONMENT="''${XDG_CACHE_HOME:-$HOME/.cache}/python-tool-venvs/${name}"
        exec ${uv} run --project ${source} --locked ${name} "$@"
      ''
    else
      ''exec ${uv} run --script ${source} "$@"'';
in
pkgs.runCommand name { meta.mainProgram = name; } ''
  install -Dm755 ${pkgs.writeShellScript name run} $out/bin/${name}

  mkdir -p $out/share/fish/vendor_completions.d
  echo '${name} --completions fish 2>/dev/null | source' \
    > $out/share/fish/vendor_completions.d/${name}.fish
''
