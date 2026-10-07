# per-user half of princeton-vpn (see ./default.nix, which imports this): the
# `princeton-vpn` command, and the app the browser hands the sign-in result to

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.lib.dotfiles) root;
in
{
  home.packages = [ (pkgs.callPackage ../python-tool.nix { } "princeton-vpn" ./princeton_vpn.py) ];

  # set the handler every time, since another app that claims the scheme (like
  # palo alto's globalprotect) would otherwise win
  home.activation.princetonVpnCallback = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${root}/tools/princeton-vpn/callback/build.sh
    run ${pkgs.duti}/bin/duti -s local.dotfiles.princeton-vpn-callback globalprotectcallback
  '';
}
