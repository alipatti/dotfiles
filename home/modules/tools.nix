# commands from the cyclopts scripts in ../../tools, with fish completions.
# both are built from the committed script, so changes need a rebuild; run
# ./tools/<name>.py directly while developing

{ lib, pkgs, ... }:
let
  names = [
    "pdf2md"
    "pawprint"
  ];

  # the toml between `# /// script` and `# ///` (pep 723)
  scriptMetadata =
    source:
    lib.pipe source [
      (lib.splitString "# /// script\n")
      (lib.flip builtins.elemAt 1)
      (lib.splitString "# ///\n")
      builtins.head
      (lib.splitString "\n")
      (map (lib.removePrefix "#"))
      (lib.concatStringsSep "\n")
      builtins.fromTOML
    ];

  # the declared dependencies that nixpkgs has. the rest must be imported
  # inside functions so the module loads without them
  python =
    source:
    pkgs.python3.withPackages (
      ps:
      lib.pipe (scriptMetadata source).dependencies [
        (map (dep: lib.toLower (builtins.head (builtins.match "([A-Za-z0-9._-]+).*" dep))))
        (builtins.filter (name: ps ? ${name}))
        (map (name: ps.${name}))
      ]
    );

  tool =
    name:
    let
      script = ../../tools/${name}.py;
    in
    pkgs.runCommand name { } ''
      mkdir -p $out/bin $out/share/fish/vendor_completions.d

      install -m755 ${script} $out/bin/${name}

      ${(python (builtins.readFile script)).interpreter} -c '
      import importlib.util
      spec = importlib.util.spec_from_file_location("tool", "${script}")
      tool = importlib.util.module_from_spec(spec)
      spec.loader.exec_module(tool)
      print(tool.app.generate_completion(shell="fish"))
      ' > $out/share/fish/vendor_completions.d/${name}.fish
    '';
in
{
  home.packages = map tool names;
}
