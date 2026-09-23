# machine-wide config for the mac. everything here runs as root at
# `darwin-rebuild switch`. per-user files live in ../home.

{ pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;

  # determinate nix manages the daemon and /etc/nix/nix.conf, not nix-darwin.
  # extra settings go in /etc/nix/nix.custom.conf
  nix.enable = false;

  # user that options like defaults and homebrew apply to
  system.primaryUser = "ali";

  # nix-darwin has to "own" the user to be allowed to set its shell
  users.knownUsers = [ "ali" ];
  users.users.ali = {
    uid = 501;
    home = "/Users/ali";
    shell = pkgs.fish;
  };

  # installs fish, adds it to /etc/shells, and sets up nix paths in /etc/fish
  programs.fish.enable = true;

  # gui apps and things that aren't in nixpkgs. nix-darwin generates a
  # brewfile and runs `brew bundle` on activation; it does not install brew.
  homebrew = {
    enable = true;
    # TODO: switch to "zap" once the old brew formulae are gone
    onActivation.cleanup = "none";

    casks = [
      # gui apps
      "kitty"
      "skim"
      "slack"
      "zoom"

      # menu bar apps
      "stats"
      "hiddenbar"

      # misc
      "the-unarchiver"
      "displaylink" # third monitor on mbp
      "tailscale-app"

      "font-cousine-nerd-font" # font for kitty
      "mactex-no-gui" # latex

      # quicklook plugins
      "qlmarkdown" # render markdown
      "syntax-highlight" # syntax highlighting for code
    ];
  };

  # https://macos-defaults.com/
  # https://nix-darwin.github.io/nix-darwin/manual/index.html#sec-options-system.defaults
  system.defaults = {
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      AppleSpacesSwitchOnActivate = true;
      AppleFontSmoothing = 1;

      NSDocumentSaveNewDocumentsToCloud = false;
      NSTextShowsControlCharacters = true;
      NSWindowResizeTime = 0.025;

      # keyboard
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      AppleKeyboardUIMode = 3; # full keyboard control
      ApplePressAndHoldEnabled = false;
      AppleWindowTabbingMode = "always";
      KeyRepeat = 1;
      InitialKeyRepeat = 20;
    };

    dock = {
      orientation = "bottom";
      tilesize = 85;
      autohide = true;
      autohide-time-modifier = 0.3;
      autohide-delay = 0.0;
      show-recents = false;
      showhidden = true; # hidden => translucent

      # spaces
      scroll-to-open = true;
      expose-group-apps = true;
      mru-spaces = false; # don't rearrange by most recently used

      # hot corners (1 = disabled)
      wvous-tl-corner = 1;
      wvous-bl-corner = 1;
      wvous-tr-corner = 1;
      wvous-br-corner = 1;

      persistent-apps = [
        { app = "/Applications/kitty.app"; }
        { app = "/Applications/Safari.app"; }
        { app = "/System/Applications/Calendar.app"; }
        { app = "/System/Applications/Reminders.app"; }
        { app = "/System/Applications/Mail.app"; }
        { app = "/Applications/Slack.app"; }
        { app = "/System/Applications/Messages.app"; }
      ];
      persistent-others = [
        {
          folder = {
            path = "/Users/ali/Downloads";
            arrangement = "date-added";
            displayas = "stack";
            showas = "fan";
          };
        }
      ];
    };

    screencapture = {
      location = "/Users/ali/Downloads";
      show-thumbnail = false;
    };

    finder = {
      ShowPathbar = true; # /path/to/folder
      ShowStatusBar = false; # xx items, xx gb remaining
      FXPreferredViewStyle = "Nlsv"; # list view
      _FXSortFoldersFirst = true;
      FXDefaultSearchScope = "SCcf"; # current folder
      FXRemoveOldTrashItems = true;
      FXEnableExtensionChangeWarning = false;
      _FXEnableColumnAutoSizing = true;
      NewWindowTarget = "Home";
    };

    spaces.spans-displays = false; # displays have separate spaces

    # require pw immediately
    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    # keys nix-darwin has no option for. written with `defaults write` as-is.
    CustomUserPreferences = {
      NSGlobalDomain.NSQuitAlwaysKeepsWindow = false;
      "com.apple.menuextra.clock".DateFormat = "EEE d MMM h:mm:ss";
      "com.apple.print.PrintingPrefs"."Quit When Finished" = true;
      "com.apple.CrashReporter".DialogType = "none";
      "com.apple.ImageCapture".disableHotPlug = false; # don't open photos when plugging in camera
      # no .DS_Store on drives/network
      "com.apple.desktopservices" = {
        DSDontWriteUSBStores = false;
        DSDontWriteNetworkStores = false;
      };
    };
  };
}
