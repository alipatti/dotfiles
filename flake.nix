{
  description = "ali's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      # per-user config shared by both hosts; see ./home
      home = extra: {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # move files home-manager wants to own out of the way instead of failing
        home-manager.backupFileExtension = "bak";
        home-manager.overwriteBackup = true;
        home-manager.users.ali.imports = [ ./home ] ++ extra;
      };

      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
          system: f nixpkgs.legacyPackages.${system}
        );
    in
    {
      # nix fmt
      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);

      # nix flake check evaluates both hosts
      checks = {
        aarch64-darwin.macbook = self.darwinConfigurations.macbook.system;
        x86_64-linux.fridge = self.nixosConfigurations.fridge.config.system.build.toplevel;
      };

      # sudo darwin-rebuild switch --flake ~/.dotfiles
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/macbook
          home-manager.darwinModules.home-manager
          (home [ ./home/darwin.nix ])
        ];
      };

      # sudo nixos-rebuild switch --flake ~/.dotfiles
      nixosConfigurations.fridge = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/fridge
          home-manager.nixosModules.home-manager
          (home [ ./home/linux.nix ])
        ];
      };
    };
}
