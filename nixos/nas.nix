{ config, pkgs, lib, ... }:

let
  uuids = [
    # TODO: add real uuids here
  ];
in {
  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  # fileSystems = builtins.listToAttrs (lib.imap0 (i: uuid: {
  #   # mount physicsl disks by uuid
  #   # https://wiki.nixos.org/wiki/Filesystems
  #   name = "/mnt/disk${toString i}";
  #   value = {
  #     device = "/dev/disk/by-uuid/${uuid}";
  #     fsType = "ext4";
  #   };
  # }) uuids) // {
  #   # create pooled virtual disk with mergerfs
  #   # https://www.reddit.com/r/NixOS/comments/18dxmwi
  #   "/storage" = {
  #     fsType = "fuse.mergerfs";
  #     device = "/mnt/disk*"; # mergerfs allows globs
  #     # TODO: check whether these are the options i want
  #     options = ["cache.files=partial" "dropcacheonclose=true" "category.create=mfs"];
  #     # don't mount until physical disks have mounted
  #     depends = lib.imap0 (i: _uuid: "/mnt/disk${toString i}");
  #   };
  # };
  
  # enable samba file sharing
  # https://wiki.nixos.org/wiki/Samba
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      test = {
        path = "/home/ali/Screenshots/";
        "read only" = false;
        # NOTE: create user with
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
