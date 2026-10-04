{ ... }:

{
  # gui apps and things that aren't in nixpkgs. nix-darwin generates a
  # brewfile and runs `brew bundle` on activation; it does not install brew.
  homebrew = {
    enable = true;
    # uninstall anything not listed here, along with its data
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

    # mac app store apps, installed with mas. needs an app store sign-in, and
    # unlike casks, apps removed from this list are not uninstalled
    masApps = {
      Hush = 1544743900;
      "uBlock Origin Lite" = 6745342698;
      Pages = 409201541;
      Numbers = 409203825;
      Xcode = 497799835;
    };
  };
}
