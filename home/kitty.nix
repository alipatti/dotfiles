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
      tab_title_template = ''"{fmt.bg._303446}{fmt.fg.color8}{fmt.fg.default}{fmt.bg.color8} {title} {fmt.bg._303446}{fmt.fg.color8}"'';
      active_tab_title_template = ''"{fmt.bg._303446}{fmt.fg._ca9ee6}{fmt.fg.tab}{fmt.bg._ca9ee6} {title} {fmt.bg._303446}{fmt.fg._ca9ee6}"'';
      active_tab_font_style = "bold";
      tab_bar_background = "none";

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
    }
    // lib.optionalAttrs isDarwin {
      macos_quit_when_last_window_closed = true;
      macos_show_window_title_in = "none";
      macos_titlebar_color = "background";
    }
    // lib.optionalAttrs (!isDarwin) {
      hide_window_decorations = true;
      wayland_titlebar_color = "background";
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
}
