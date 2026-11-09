# per-user config for hpc clusters without root. the flake builds one
# home-manager config per entry in `clusters`, each with `module`

{
  # cluster name = my username there. ./setup picks the entry from the
  # hostname with trailing digits dropped (adroit5 -> adroit)
  clusters = {
    adroit = "ap1741";
  };

  module =
    {
      config,
      pkgs,
      lib,
      ...
    }:
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

      nix.package = pkgs.nix;
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # collect garbage on every switch. nix.gc.automatic needs a systemd user
      # timer, which login nodes don't run. -d also drops old generations, so
      # there is no rollback, but the store stays under quota
      home.activation.gc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${config.nix.package}/bin/nix-collect-garbage -d
      '';
    };
}
