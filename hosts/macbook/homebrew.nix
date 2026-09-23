{ ... }:

{
  # gui apps and things that aren't in nixpkgs. nix-darwin generates a
  # brewfile and runs `brew bundle` on activation; it does not install brew.
  homebrew = {
    enable = true;
    # uninstall anything not listed here
    onActivation.cleanup = "zap";

    casks = [
      # gui apps
      "skim"
      "slack"
      "zoom"
      "spotify"
      "whatsapp"
      "claude"
      "chatgpt"
      "paseo"
      "sage" # sagemath

      # menu bar apps
      "stats"
      "hiddenbar"

      # misc
      "the-unarchiver"
      "displaylink" # third monitor on mbp
      "tailscale-app"


      # quicklook plugins
      "qlmarkdown" # render markdown
      "syntax-highlight" # syntax highlighting for code
      "qlcolorcode"
      "qlstephen" # preview files without an extension
    ];
  };
}
