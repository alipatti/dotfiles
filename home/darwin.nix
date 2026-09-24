# per-user config that only makes sense on a mac

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.lib.dotfiles) root link;
in
{
  # on nixos this docker stuff is handled by virtualisation.docker
  home.packages = with pkgs; [
    docker-client
    docker-compose
    docker-buildx
    lima-additional-guestagents
    qemu
  ];

  # sets DOCKER_CONFIG and writes the config.json there
  programs.docker-cli = {
    enable = true;
    settings.cliPluginsExtraDirs = [
      "${pkgs.docker-compose}/libexec/docker/cli-plugins"
      "${pkgs.docker-buildx}/libexec/docker/cli-plugins"
    ];
  };

  # runs the vm as a launchd agent and sets the docker context
  services.colima.enable = true;

  home.file = {
    # mac-specific config locations
    "Library/texmf/tex/latex/local".source = link "latex";
    "Library/Application Support/typst/packages/ali".source = link "typst";
  };

  # macos defaults live in ../hosts/macbook/defaults.nix. these two are the
  # exceptions nix-darwin has no option for
  targets.darwin.search = "DuckDuckGo";
  # don't open photos when plugging in a camera. a per-host key, so it goes
  # through -currentHost
  targets.darwin.currentHostDefaults."com.apple.ImageCapture".disableHotPlug = true;

  # hidutil remap, reapplied at login by a launchd agent
  services.macos-remap-keys = {
    enable = true;
    keyboard.Capslock = "Escape";
  };

  # build the webview helper if the source is newer than the binary
  home.activation.webview = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    src=${root}/tools/webview.swift
    bin=$HOME/.local/bin/webview
    if [ ! "$bin" -nt "$src" ]; then
      run mkdir -p "$HOME/.local/bin"
      run /usr/bin/swiftc -O "$src" -o "$bin"
    fi
  '';
}
