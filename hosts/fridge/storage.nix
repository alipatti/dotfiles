# the 8 sas disks as one raidz2 pool, mounted at /storage, with a partition of
# the nvme as a read cache (l2arc). writes are buffered in ram, so only reads
# need the cache.
#
# pool creation is a one-time step, run after this config is deployed:
#   sudo zpool create -o ashift=12 \
#     -O mountpoint=/storage -O compression=lz4 -O atime=off \
#     -O xattr=sa -O acltype=posixacl -O recordsize=1M \
#     tank raidz2 /dev/disk/by-id/<8 disks>
#   sudo chown ali:users /storage
# and once the nvme has a free partition (root has to be shrunk offline first):
#   sudo zpool add tank cache /dev/disk/by-id/<nvme partition>
{
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "faba0154"; # required by zfs, any random 8 hex digits
  boot.zfs.extraPools = [ "tank" ];
  boot.zfs.forceImportRoot = false; # root isn't on zfs; the default goes false in 26.11

  boot.extraModprobeConfig = ''
    # leave most of the 32gb ram to polars
    options zfs zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}
    # cache sequential reads (parquet scans) in l2arc, which skips them by default
    options zfs l2arc_noprefetch=0
    # fill l2arc at 256mb/s instead of the default 8mb/s
    options zfs l2arc_write_max=${toString (256 * 1024 * 1024)}
    options zfs l2arc_write_boost=${toString (512 * 1024 * 1024)}
  '';

  services.zfs.autoScrub.enable = true; # monthly
  services.zfs.trim.enable = true;
}
