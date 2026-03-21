{ pkgs, lib, ... }:

let
  uuids = [
    "1562653e-05ee-4b0b-8227-b88c2f11a4ab"
    "3e3deb36-9126-4528-a18a-2a9701374b10"
    "430dba61-fc90-48c6-a114-52398cd5b192"
    "54f8e608-8c2f-463b-b967-c6a649688bbf"
    "57adfbb4-47eb-4878-89c0-9c4750684bb9"
    "9a8bf894-d4bb-4e91-9911-ab26268be345"
    "b0cf688c-38b3-4d8c-8385-5c362b3c6bba"
    "bbab62ae-0520-4e7c-8d43-9c2f9c4c44b0"
    "cb85c0d8-b25a-461f-bb4c-bd0637f60c87"
    "ee53aff8-f22a-429d-aac1-77abddd26f15"
  ];
in
{
  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  fileSystems =
    # mount physicsl disks by uuid
    # https://wiki.nixos.org/wiki/Filesystems
    builtins.listToAttrs (
      lib.imap0 (i: uuid: {
        name = "/mnt/disk${toString i}";
        value = {
          device = "/dev/disk/by-uuid/${uuid}";
          fsType = "ext4";
        };
      }) uuids
    )
    # create pooled virtual disk with mergerfs
    # https://www.reddit.com/r/NixOS/comments/18dxmwi
    // {
      "/storage" = {
        fsType = "fuse.mergerfs";
        device = "/mnt/disk*"; # mergerfs allows globs
        options = [
          # TODO: check whether these are the options i want
          "cache.files=partial"
          "dropcacheonclose=true"
          "category.create=lfs"
        ];
        # don't mount until physical disks have mounted
        depends = lib.imap0 (i: _uuid: "/mnt/disk${toString i}") uuids;
      };
    };

  # enable samba file sharing
  # https://wiki.nixos.org/wiki/Samba
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      drive_pool = {
        path = "/storage";
        "read only" = false;
        # NOTE: create user with
        # sudo smbpasswd -a ali
        "valid users" = "ali";
      };
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
}
