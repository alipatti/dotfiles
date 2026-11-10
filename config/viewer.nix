# the viewer command (apps/viewer), on every machine. on macos it opens
# viewer.app, which is built here

{
  config,
  pkgs,
  lib,
  ...
}:
let
  # copied into the store, so the build below reruns whenever the sources change
  src = builtins.path {
    name = "viewer-source";
    path = ../apps/viewer;
  };
  app = "$HOME/Applications/viewer.app";
in
{
  # at a fixed path, since kitty runs it on the mac for remote hosts. force
  # replaces the command an older build wrote here
  home.file.".local/bin/viewer" = {
    source = lib.getExe pkgs.viewer;
    force = true;
  };

  # this uses the system swiftc rather than nixpkgs', so the app links against
  # the current sdk. appkit leaves out newer features (window tiling shortcuts,
  # the macos 26 look) for apps built against older ones. the link to the
  # sources it was built from is written last, so it also marks a finished build
  home.activation.viewer = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      built=${app}/Contents/Resources/source
      if [ "$(readlink "$built")" != ${src} ]; then
        run mkdir -p ${app}/Contents/MacOS ${app}/Contents/Resources
        run cp -f ${src}/Info.plist ${app}/Contents/Info.plist
        run /usr/bin/swiftc -O ${src}/viewer.swift -o ${app}/Contents/MacOS/viewer
        run ln -sfn ${src} "$built"
      fi
    ''
  );
}
