{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.rumdl ];

  xdg.configFile."rumdl/rumdl.toml".source = (pkgs.formats.toml { }).generate "rumdl.toml" {
    global.extend-enable = [ "table-format" ];

    code-block-tools = {
      enabled = true;
      languages.python.format = [ "ruff:format" ];
    };

    line-length = {
      line-length = 75;
      reflow = true;
      reflow-mode = "semantic-line-breaks";
      math-blocks = false;
      code-blocks = false;
    };

    table-format.enabled = true;
  };

  # format markdown claude edits with the config above. mkBefore keeps it
  # ahead of the nvim reload hook in ./agents.nix so the buffer picks up the
  # formatted file. anything rumdl can't fix is fed back via exit code 2
  programs.claude-code.settings.hooks.PostToolUse = lib.mkBefore [
    {
      matcher = "Edit|MultiEdit|Write";
      hooks = [
        {
          type = "command";
          command = toString (
            pkgs.writeShellScript "rumdl-hook" ''
              f=$(${lib.getExe pkgs.jq} -r '.tool_input.file_path // empty')
              case "$f" in *.md) ;; *) exit 0 ;; esac
              [ -f "$f" ] || exit 0
              out=$(${lib.getExe pkgs.rumdl} fmt --quiet --color never "$f" 2>&1 | ${lib.getExe pkgs.gnugrep} -v '\[fixed\]$')
              [ -z "$out" ] && exit 0
              printf 'rumdl could not auto-fix:\n%s\n' "$out" >&2
              exit 2
            ''
          );
        }
      ];
    }
  ];
}
