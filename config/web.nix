# web development: js toolchain and the editor's web language servers, which
# are enabled in ./nvim/plugin/lsp.lua. clusters skip this module

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs
    pnpm
    svelte-language-server
    tailwindcss-language-server
  ];

  programs.fish.shellAbbrs.npm = "pnpm";
}
