# per-user config that only makes sense on a mac

{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.file = {
    "Library/texmf/tex/latex/local".source = link "latex";
    "Library/Application Support/papis/config".source = link "papis/config";
    "Library/Application Support/typst/packages/ali".source = link "typst/packages";
  };

  # default apps for file types
  home.activation.duti = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.duti}/bin/duti ${dotfiles}/macos/default-apps.duti
  '';

  # build the webview helper if the source is newer than the binary
  home.activation.webview = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    src=${dotfiles}/macos/webview.swift
    bin=$HOME/.local/bin/webview
    if [ ! "$bin" -nt "$src" ]; then
      run mkdir -p "$HOME/.local/bin"
      run /usr/bin/swiftc -O "$src" -o "$bin"
    fi
  '';
}
