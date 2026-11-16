# reachable at smb://fridge/storage over tailscale, or found in finder's
# sidebar on the local network via avahi
{
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      # better behavior with macos clients (resource forks, finder metadata)
      global = {
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:posix_rename" = "yes";
      };
      storage = {
        path = "/storage";
        "read only" = false;
        # NOTE: create user with
        # sudo smbpasswd -a ali
        "valid users" = "ali";
      };
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true; # allow .local
      userServices = true; # needed for samba
    };
  };
}
