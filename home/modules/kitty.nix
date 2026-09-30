# kitty terminal. on macos the app bundle ends up in
# ~/Applications/Home Manager Apps. docs: https://sw.kovidgoyal.net/kitty/conf/

{
  config,
  pkgs,
  lib,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  split = "${config.lib.dotfiles.root}/tools/kitty_split.py";
  bridge = "${config.lib.dotfiles.root}/tools/kitty_bridge.py";
  # authenticate messages to the bridge (see its docstring for why two).
  # outside the nix store, which anyone on the machine can read, and under
  # the same paths the watcher reads
  secrets = map (name: "${config.home.homeDirectory}/.local/state/${name}") [
    "kitty-bridge-secret"
    "kitty-bridge-remote-secret"
  ];

  # tab templates are python f-strings, so remote tabs can use different
  # colors. fish_title prefixes {host} when $SSH_TTY is set; the ssh check
  # covers hosts without this config. `sshOr yes no` takes a layer (fg/bg)
  remote = "title.startswith('{') or tab.active_exe == 'ssh'";
  sshOr =
    yes: no: layer:
    "{fmt.${layer}.${yes} if ${remote} else fmt.${layer}.${no}}";
  pill =
    color: text:
    ''"{fmt.bg._303446}${color "fg"}${text "fg"}${color "bg"} {title} {fmt.bg._303446}${color "fg"}"'';
in
{
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.cousine;
      name = "Cousine Nerd Font Mono";
      size = 14;
    };
    themeFile = "Catppuccin-Frappe";

    # fish sources the integration itself; the title comes from fish_title
    shellIntegration.mode = "no-title";

    settings = {
      # tab bar
      tab_bar_min_tabs = 1;
      tab_bar_margin_width = 5;
      tab_bar_margin_height = "15 10";
      tab_fade = 0;
      tab_title_template = pill (sshOr "color8" "color8") (sshOr "_ef9f76" "default");
      active_tab_title_template = pill (sshOr "_ef9f76" "_ca9ee6") (sshOr "tab" "tab");
      active_tab_font_style = "bold";
      tab_bar_background = "none";

      # the default shape, so it also applies over ssh where kitty's shell
      # integration isn't loaded
      cursor_shape = "beam";

      # dim inactive windows
      inactive_text_alpha = 0.45;

      # window
      window_padding_width = "0 15";
      remember_window_size = false;
      initial_window_width = "120c";
      initial_window_height = "40c";

      # goto_layout only matches names listed here, so the bias has to be set here
      enabled_layouts = "tall:bias=60,fat:bias=60,stack";

      # remote control
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-{kitty_pid}";
      # lets nvim open and drive windows, also from remote hosts
      watcher = bridge;
    }
    // lib.optionalAttrs isDarwin {
      # kitty starts from launchd with a bare PATH. programs it runs directly,
      # without a shell in between (e.g. `kitten @ launch claude` from nvim),
      # would otherwise miss the nix profile paths that fish sets up
      env = "read_from_shell=PATH";

      macos_quit_when_last_window_closed = true;
      macos_show_window_title_in = "none";
      macos_titlebar_color = "background";
    }
    // lib.optionalAttrs (!isDarwin) {
      hide_window_decorations = true;
    };

    keybindings = {
      "ctrl+;" = "toggle_layout stack";
      "ctrl+." = "next_window";
      "ctrl+," = "previous_window";

      # splits
      "kitty_mod+enter" = "remote_control_script ${split}";
      "cmd+enter" = "remote_control_script ${split}";
    }
    // lib.optionalAttrs (!isDarwin) {
      "shift+ctrl+]" = "next_tab";
      "shift+ctrl+[" = "prev_tab";
      "ctrl+t" = "new_tab";
    };
  };

  home.activation.kittyBridgeSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStrings (secret: ''
      if [ ! -f ${secret} ]; then
        run mkdir -p "$(dirname ${secret})"
        (umask 077 && ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > ${secret})
      fi
    '') secrets
  );

  # settings for `kitten ssh`. a hostname block starts from the defaults, so
  # each host lists everything it needs
  xdg.configFile."kitty/ssh.conf".text = ''
    hostname adroit
    # the bridge's remote secret, under the name nvim reads there. kept 0600
    copy --dest=.local/state/kitty-bridge-secret .local/state/kitty-bridge-remote-secret
    # the account's login shell is bash outside the nix chroot, so commands
    # run over ssh (e.g. windows opened by the bridge) wouldn't find anything.
    # this wrapper from ../../setup enters the chroot first
    login_shell /home/ap1741/.local/bin/fish
  '';
}
