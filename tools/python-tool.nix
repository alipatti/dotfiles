# builds a command from a cyclopts script with a pep 723 header, with fish
# completions. both come from the committed script, so changes need a rebuild;
# run the script directly while developing. the script's `app` must be named
# `name` (`App(name="pawprint")`), since completions are generated for it
#
#   pkgs.callPackage ../python-tool.nix { } "pawprint" ./pawprint.py

{ lib, pkgs }:
name: script:
let
  # the toml between `# /// script` and `# ///` (pep 723)
  metadata = lib.pipe (builtins.readFile script) [
    (lib.splitString "# /// script\n")
    (lib.flip builtins.elemAt 1)
    (lib.splitString "# ///\n")
    builtins.head
    (lib.splitString "\n")
    (map (lib.removePrefix "#"))
    (lib.concatStringsSep "\n")
    builtins.fromTOML
  ];

  # pep 503 names, e.g. "Python_Dateutil>=2" -> "python-dateutil", which is how
  # nixpkgs names most python packages
  normalize =
    dependency:
    lib.pipe dependency [
      (builtins.match "([A-Za-z0-9._-]+).*")
      builtins.head
      lib.toLower
      (builtins.replaceStrings [ "_" "." ] [ "-" "-" ])
    ];

  # the declared dependencies that nixpkgs has. the rest must be imported
  # inside functions so the module loads without them
  python = pkgs.python3.withPackages (
    ps:
    lib.pipe (metadata.dependencies or [ ]) [
      (map normalize)
      (builtins.filter (name: ps ? ${name}))
      (map (name: ps.${name}))
    ]
  );
in
pkgs.runCommand name { } ''
  mkdir -p $out/bin $out/share/fish/vendor_completions.d

  install -m755 ${script} $out/bin/${name}

  ${python.interpreter} -c '
  import importlib.util
  spec = importlib.util.spec_from_file_location("tool", "${script}")
  tool = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(tool)
  print(tool.app.generate_completion(shell="fish"))
  ' > $out/share/fish/vendor_completions.d/${name}.fish
''
