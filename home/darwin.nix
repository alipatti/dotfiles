# per-user config that only makes sense on a mac

{ config, pkgs, lib, ... }:
let
  inherit (config.lib.dotfiles) link;
in
{
  home.packages = with pkgs; [
    # on nixos this docker stuff is handled by virtualisation.docker
    docker-client
    docker-compose
    docker-buildx
    colima
    lima-additional-guestagents
    qemu
  ];

  home.file = {
    # docker cli only looks for plugins here, not in the nix profile
    ".docker/cli-plugins/docker-compose".source = "${pkgs.docker-compose}/bin/docker-compose";
    ".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/bin/docker-buildx";

    # mac-specific config locations
    "Library/texmf/tex/latex/local".source = link "latex";
    "Library/Application Support/typst/packages/ali".source = link "typst";
  };

  # per-user `defaults write` for keys nix-darwin has no option for
  # https://macos-defaults.com/
  targets.darwin.defaults = {
    NSGlobalDomain.NSQuitAlwaysKeepsWindow = false;
    "com.apple.menuextra.clock".DateFormat = "EEE d MMM h:mm:ss";
    "com.apple.print.PrintingPrefs"."Quit When Finished" = true;
    "com.apple.CrashReporter".DialogType = "none";
    # no .DS_Store on drives/network
    "com.apple.desktopservices" = {
      DSDontWriteUSBStores = true;
      DSDontWriteNetworkStores = true;
    };
  };

  # don't open photos when plugging in a camera. a per-host key, so it goes
  # through -currentHost
  targets.darwin.currentHostDefaults."com.apple.ImageCapture".disableHotPlug = true;

  # default safari search engine
  targets.darwin.search = "DuckDuckGo";

  # hidutil remap, reapplied at login by a launchd agent
  services.macos-remap-keys = {
    enable = true;
    keyboard.Capslock = "Escape";
  };

  # build the webview helper if the source is newer than the binary
  home.activation.webview = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    src=${config.home.homeDirectory}/.dotfiles/tools/webview.swift
    bin=$HOME/.local/bin/webview
    if [ ! "$bin" -nt "$src" ]; then
      run mkdir -p "$HOME/.local/bin"
      run /usr/bin/swiftc -O "$src" -o "$bin"
    fi
  '';
}
