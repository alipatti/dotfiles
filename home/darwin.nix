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

  programs.docker-cli = {
    enable = true;
    settings.cliPluginsExtraDirs = [
      "${pkgs.docker-compose}/libexec/docker/cli-plugins"
      "${pkgs.docker-buildx}/libexec/docker/cli-plugins"
    ];
  };

  services.colima = {
    enable = true;
    # don't start vm at launch. hogs memory.
    profiles.default.isService = false;
  };

  home.file = {
    # mac-specific config locations
    "Library/Application Support/typst/packages/ali".source = link "typst";
  };

  targets.darwin.search = "DuckDuckGo";

  # hidutil remap, reapplied at login by a launchd agent
  services.macos-remap-keys = {
    enable = true;
    keyboard.Capslock = "Escape";
  };

  # use textedit to open text files instead of xcode
  home.activation.fileHandlers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for uti in \
      public.source-code public.script public.python-script public.shell-script \
      net.daringfireball.markdown public.json public.yaml public.xml \
      public.swift-source public.c-source public.c-header public.c-plus-plus-source \
      com.netscape.javascript-source; do
      if [ "$(${pkgs.duti}/bin/duti -d "$uti")" != com.apple.TextEdit ]; then
        run ${pkgs.duti}/bin/duti -s com.apple.TextEdit "$uti" all
      fi
    done
  '';

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
