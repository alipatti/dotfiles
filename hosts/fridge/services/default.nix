{ config, lib, ... }:

let
  domain = "fridge.alipatti.com";
  ip = "100.100.1.1";
  files = lib.filterAttrs (
    name: type: type == "regular" && name != "default.nix" && lib.hasSuffix ".nix" name
  ) (builtins.readDir ./.);
in
{
  imports = map (name: ./${name}) (builtins.attrNames files);

  options.fridge.expose = lib.mkOption {
    type = lib.types.attrsOf lib.types.port;
    default = { };
    description = "local ports to serve at <name>.${domain}";
  };

  config = {
    # answer only *.fridge.alipatti.com for tailscale's split dns
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        interface = "tailscale0";
        bind-dynamic = true; # tailscale0 can appear after dnsmasq starts
        no-resolv = true;
        address = "/${domain}/${ip}";
      };
    };

    # plain http for now
    services.caddy = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        name: port:
        lib.nameValuePair "http://${name}.${domain}" {
          extraConfig = "reverse_proxy localhost:${toString port}";
        }
      ) config.fridge.expose;
    };
  };
}
