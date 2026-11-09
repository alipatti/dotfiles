# ~/.ssh/config is generated from this. keys and known_hosts are plain files
# in ~/.ssh that nix doesn't touch

{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;
    # don't emit home-manager's legacy default block
    enableDefaultConfig = false;
    includes = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      "~/${config.services.colima.colimaHomeDir}/ssh_config"
    ];
    settings.fasrc = {
      HostName = "login.rc.fas.harvard.edu";
      User = "alipatti";
    };
    settings.adroit = {
      HostName = "adroit.princeton.edu";
      User = "ap1741";
    };
    # one connection per host, shared by ssh, scp, rsync, git and kitten ssh,
    # so 2fa is only asked once. after sleep or a network change, a dead master
    # can make new connections hang until ServerAlive notices or `ssh -O exit`
    settings."fasrc adroit fridge" = {
      ControlMaster = "auto";
      ControlPath = "~/.ssh/cm-%C";
      ControlPersist = "10m";
      ServerAliveInterval = 30;
    };
  };
}
