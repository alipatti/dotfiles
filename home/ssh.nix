# ~/.ssh/config is generated from this. keys and known_hosts are plain files
# in ~/.ssh that nix doesn't touch

{
  programs.ssh = {
    enable = true;
    # don't emit home-manager's legacy default block
    enableDefaultConfig = false;
    includes = [
      "~/.config/colima/ssh_config"
    ];
    settings.fasrc = {
      HostName = "login.rc.fas.harvard.edu";
      User = "alipatti";
    };
  };
}
