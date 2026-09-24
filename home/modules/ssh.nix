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
  };
}
