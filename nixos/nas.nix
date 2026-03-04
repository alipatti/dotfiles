{ config, pkgs, lib, ... }:

let
  uuids = [
    # TODO: add real uuids
    "uuid-1"
    "uuid-2"
    "uuid-3"
  ];
in {
  fileSystems = builtins.listToAttrs (lib.imap0 (i: uuid: {
    # mount physicsl disks by uuid
    # https://wiki.nixos.org/wiki/Filesystems
    name = "/mnt/disk${toString i}";
    value = {
      device = "/dev/disk/by-uuid/${uuid}";
      fsType = "ext4";
    };
  }) uuids) // {
    # create pooled virtual disk with mergerfs
    # https://www.reddit.com/r/NixOS/comments/18dxmwi
    "/storage" = {
      fsType = "fuse.mergerfs";
      device = "/mnt/disk*"; # mergerfs allows globs
      # TODO: check whether these are the options i want
      options = ["cache.files=partial" "dropcacheonclose=true" "category.create=mfs"];
      # don't mount until physical disks have mounted
      depends = lib.imap0 (i: _uuid: "/mnt/disk${toString i}")
    };
  };

  environment.systemPackages = with pkgs; [
    mergerfs
  ];
  
  # enable samba file sharing
  # https://wiki.nixos.org/wiki/Samba
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      share = {
        path = "/storage";
        "read only" = false;
        # NOTE: still need to create user with
        # sudo smbpasswd -a ali
        "valid users" = "ali";
      };
    };
  };

  # advertise services
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true; # allow .local
      userServices = true; # needed for samba
    };
  };

  # TODO: configure wireguard

  # TODO: configure *arr stack
}
