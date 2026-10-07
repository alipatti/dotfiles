# nix-darwin module for `princeton-vpn`, princeton's globalprotect vpn over
# openconnect, for campus traffic only. this half runs openconnect as root;
# the command and the sign-in callback app are per-user, in ./home.nix
#
# the command runs the wrapper below with sudo (touch id), once per connection.
# the wrapper fixes openconnect's arguments and environment, so root only
# ever runs this tunnel

{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.system.primaryUser;

  # one of the prisma access gateways that vpn.princeton.edu lists in the
  # config it returns after sign-in (global-protect/getconfig.esp)
  gateway = "us-east-g-princeto.gpogn2y5gg2j.gw.gpcloudservice.com";

  # princeton's ipv4 blocks (AS88). the clusters have no ipv6 addresses
  campus = [
    "128.112.0.0/16"
    "140.180.0.0/16"
    "66.180.176.0/20"
    "204.153.48.0/22"
    "205.172.164.0/22"
  ];

  # vpn-slice also routes the dns servers the gateway pushes, whatever they
  # are, and names them in /etc/hosts. drop them so only campus is routed and
  # the resolver and /etc/hosts are left alone
  slice = lib.concatStringsSep " " (
    [
      "/usr/bin/env -u INTERNAL_IP4_DNS -u INTERNAL_IP6_DNS -u INTERNAL_IP4_NBNS"
      "${pkgs.vpn-slice}/bin/vpn-slice --no-ns-hosts"
    ]
    ++ campus
  );

  tunnel = pkgs.writeShellApplication {
    name = "princeton-vpn-tunnel";
    text = ''
      # usage: princeton-vpn-tunnel <netid>@princeton.edu, with the portal
      # cookie on stdin
      if [[ $# -ne 1 || ! $1 =~ ^[a-z0-9]+@princeton\.edu$ ]]; then
        echo "usage: princeton-vpn-tunnel <netid>@princeton.edu" >&2
        exit 64
      fi

      # a clean environment, so the caller's PATH (where vpn-slice looks for
      # route and pfctl), HOME and proxy settings don't reach root
      exec /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        ${pkgs.openconnect}/bin/openconnect \
        --protocol=gp \
        --os=mac-intel \
        --user="$1" \
        --usergroup=gateway:portal-userauthcookie \
        --passwd-on-stdin \
        --non-inter \
        --script=${lib.escapeShellArg slice} \
        ${gateway}
    '';
  };
in
{
  environment.systemPackages = [ tunnel ];

  home-manager.users.${user}.imports = [ ./home.nix ];
}
