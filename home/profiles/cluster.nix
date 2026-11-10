# per-user config for hpc clusters without root. the flake builds one
# home-manager config per entry in `clusters`, each with `module`

{
  # cluster name = my home directory there (the username is its last part).
  # ./setup picks the entry from the hostname with trailing digits dropped
  # (adroit5 -> adroit), or from its argument (./setup cannon)
  clusters = rec {
    adroit = "/home/ap1741";
    cannon = "/n/home13/alipatti";
    # cannon login nodes (login.rc.fas.harvard.edu picks one of these)
    boslogin = cannon;
    holylogin = cannon;
  };

  module =
    { pkgs, ... }:
    {
      imports = [
        # cherry-pick necessary parts. the other profiles import all of ../programs
        ../programs/agents
        ../programs/fish
        ../programs/git
        ../programs/languages.nix
        ../programs/latex.nix
        ../programs/nvim
        ../programs/packages.nix
        ../programs/prompt.nix
        ../programs/python
        ../programs/rumdl.nix
        ../programs/ssh.nix
        ../programs/typst.nix
        ../programs/viewer.nix
      ];

      # `trash`. macos has its own, and fridge gets it from linux.nix
      home.packages = [ pkgs.trashy ];

      # xdg paths, locale and terminfo for nix programs on a non-nixos distro
      targets.genericLinux.enable = true;
      # driver setup needs sudo. gpu work uses module/pip cuda, not nix
      targets.genericLinux.gpu.enable = false;

      # no garbage collection on switch: the flake inputs aren't gc roots, so it
      # would delete nixpkgs and every ./setup would re-unpack it onto nfs. run
      # `nix-collect-garbage -d` by hand when the home quota gets tight
      nix.package = pkgs.nix;
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
}
