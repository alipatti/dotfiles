{ lib, ... }:
{
  programs.starship = {
    enable = true;
    settings = {
      format = lib.concatStrings [
        "$directory"
        "$username"
        "$hostname"
        "$sudo"
        "$cmd_duration"
        "$fill"
        "$rust"
        "$python"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$git_metrics"
        "$line_break"
        "$jobs"
        "$battery"
        "$status"
        "$container"
        "$character"
      ];

      fill.symbol = " ";

      cmd_duration = {
        format = "[ $duration]($style) ";
        style = "bright-black";
      };

      sudo = {
        format = "[\\(as sudo\\)]($style)";
        disabled = false;
      };

      hostname = {
        format = "[@$hostname](bright-white) ";
      };

      username = {
        format = "[– $user](bright-white)";
      };

      # languages
      python = {
        format = "[ \${version} $virtualenv | ](bright-white)";
        detect_extensions = [ ];
        detect_files = [ ];
        detect_folders = [ ];
        version_format = "$v\${major}.\${minor}";
      };
      rust = {
        format = "[ \${version} | ](bright-white)";
        version_format = "$v\${major}.\${minor}";
      };

      # git
      git_branch.format = "[ $branch ](bright-white)";
      git_status.format = "[$conflicted$stashed$deleted$renamed$typechanged$staged$untracked$ahead_behind](red) ";
      git_metrics = {
        format = "([+$added](green) )([-$deleted](red) )";
        ignore_submodules = true;
        disabled = false;
      };
    };
  };
}
