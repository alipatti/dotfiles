# smb://fridge/<user>
{
  services.samba = {
    enable = true;
    settings = {
      # macos client support
      global = {
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:posix_rename" = "yes";
      };
      # NOTE: add user with `sudo smbpasswd -a ali`
      homes = {
        browseable = "no"; # list as username, not "homes"
        "read only" = "no";
        "valid users" = "%S"; # only the owner
      };
    };
  };
}
