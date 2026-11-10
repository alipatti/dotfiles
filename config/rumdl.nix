{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.rumdl ];

  xdg.configFile."rumdl/rumdl.toml".source = (pkgs.formats.toml { }).generate "rumdl.toml" {
    global.extend-enable = [ "table-format" ];

    # python code blocks are formatted by ruff through uvx, like everywhere
    # else, rather than a ruff from nixpkgs. rumdl's built-in "ruff:format"
    # can't be pointed at uvx, so this defines its own tool
    code-block-tools = {
      enabled = true;
      tools.uvx-ruff-format = {
        command = [
          (lib.getExe pkgs.uv)
          "tool"
          "run"
          "ruff"
          "format"
          "-"
        ];
        stdin = true;
        stdout = true;
      };
      languages.python.format = [ "uvx-ruff-format" ];
    };

    line-length = {
      line-length = 75;
      reflow = true;
      reflow-mode = "semantic-line-breaks";
      math-blocks = false;
      code-blocks = false;
    };

    table-format.enabled = true;

    # agent skills: reflow splits a !`command` line after the `!`, which
    # breaks it, and a skill whose whole body is the prompt has no heading
    per-file-ignores."**/skills/**/*.md" = [
      "MD013"
      "MD041"
    ];
  };

  # format markdown claude edits with the config above. mkBefore keeps it
  # ahead of the nvim reload hook in ./agents so the buffer picks up the
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
