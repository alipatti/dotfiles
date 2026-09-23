{ ... }:

{
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
        { app = "/Applications/Claude.app"; }
        { app = "/System/Cryptexes/App/System/Applications/Safari.app"; }
        { app = "/System/Applications/Calendar.app"; }
        { app = "/System/Applications/Reminders.app"; }
        { app = "/System/Applications/Mail.app"; }
        { app = "/Applications/Slack.app"; }
        { app = "/Applications/WhatsApp.app"; }
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
  };
}
