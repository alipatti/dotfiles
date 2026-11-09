# papis bibliography manager. on macos papis looks for its config in
# ~/Library/Application Support, so point it at the xdg file home-manager
# writes instead

{ config, ... }:
let
  key = "{doc[author_list][0][family]} {doc[year]} {doc[title]:.15}";
in
{
  programs.papis = {
    enable = true;

    libraries = {
      papers = {
        isDefault = true;
        settings.dir = "~/Documents/library/papers";
      };
      books.settings.dir = "~/Documents/library/books";
    };

    settings = {
      use-git = true;

      # naming
      ref-word-separator = "-";
      ref-format = key;
      add-folder-name = key;
      add-file-name = key;
    };
  };

  home.sessionVariables.PAPIS_CONFIG_DIR = "${config.xdg.configHome}/papis";
}
