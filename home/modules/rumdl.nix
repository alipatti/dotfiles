{ pkgs, ... }:
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
}
