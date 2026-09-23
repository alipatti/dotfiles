# per-user config that only makes sense on a mac

{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  links = builtins.fromTOML (builtins.readFile ../links.toml);
in
{
  # docker. on nixos this is handled by virtualisation.docker instead
  home.packages = with pkgs; [
    docker-client
    docker-compose
    docker-buildx
    colima # open source docker runtime
    lima-additional-guestagents
    qemu
  ];

  home.file = {
    # docker cli only looks for plugins here, not in the nix profile
    ".docker/cli-plugins/docker-compose".source = "${pkgs.docker-compose}/bin/docker-compose";
    ".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/bin/docker-buildx";
  }
  // lib.mapAttrs' (
    target: source: lib.nameValuePair (lib.removePrefix "~/" target) { source = link source; }
  ) links.darwin;

  # build the webview helper if the source is newer than the binary
  home.activation.webview = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    src=${dotfiles}/darwin/webview.swift
    bin=$HOME/.local/bin/webview
    if [ ! "$bin" -nt "$src" ]; then
      run mkdir -p "$HOME/.local/bin"
      run /usr/bin/swiftc -O "$src" -o "$bin"
    fi
  '';
}
