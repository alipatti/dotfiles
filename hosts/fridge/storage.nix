# 8 disk raidz2 pool at ~/storage, with an nvme partition as read cache
#
# one-time setup:
#   sudo zpool create -o ashift=12 \
#     -O mountpoint=/home/ali/storage -O compression=lz4 -O atime=off \
#     -O xattr=sa -O acltype=posixacl -O recordsize=1M \
#     tank raidz2 /dev/disk/by-id/<8 disks>
#   sudo chown ali:users /home/ali/storage
#   sudo zpool add tank cache /dev/disk/by-id/<nvme partition>
{
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "faba0154"; # random, required by zfs
  boot.zfs.extraPools = [ "tank" ];
  boot.zfs.forceImportRoot = false; # default from 26.11

  boot.extraModprobeConfig = ''
    # cap ram cache
    options zfs zfs_arc_max=${toString (4 * 1024 * 1024 * 1024)}

    # cache sequential reads (skipped by default)
    options zfs l2arc_noprefetch=0

    # fill cache faster (default 8mb/s)
    options zfs l2arc_write_max=${toString (256 * 1024 * 1024)}
    options zfs l2arc_write_boost=${toString (512 * 1024 * 1024)}
  '';

  services.zfs.autoScrub.enable = true; # monthly
  services.zfs.trim.enable = true;
}
