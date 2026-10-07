# home-manager module for `pdf2md`, on every machine

{ pkgs, ... }:
{
  home.packages = [
    (pkgs.callPackage ../python-tool.nix { } "pdf2md" ./pdf2md.py)
    pkgs.llama-cpp # llama-server, used by marker's ocr models
  ];
}
