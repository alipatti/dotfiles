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
      # shared by both hosts. per-user config is in ./home, and the profile
      # (./home/profiles) picks which programs a host gets
      common = profile: {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [ self.overlays.default ];

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # move files home-manager wants to own out of the way instead of failing
        home-manager.backupFileExtension = "bak";
        home-manager.overwriteBackup = true;
        home-manager.users.ali.imports = [
          ./home
          profile
        ];
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

      # software written here (./apps), as pkgs.<name> through the overlay
      overlays.default = final: prev: import ./apps final;
      packages = forEachSystem (pkgs: import ./apps pkgs);

      # nix flake check builds the apps and evaluates both hosts
      checks = {
        aarch64-darwin = self.packages.aarch64-darwin // {
          macbook = self.darwinConfigurations.macbook.system;
        };
        x86_64-linux = self.packages.x86_64-linux // {
          fridge = self.nixosConfigurations.fridge.config.system.build.toplevel;
        };
      };

      # sudo darwin-rebuild switch --flake ~/.dotfiles
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        modules = [
          ./hosts/macbook
          home-manager.darwinModules.home-manager
          (common ./home/profiles/darwin.nix)
        ];
      };

      # sudo nixos-rebuild switch --flake ~/.dotfiles
      nixosConfigurations.fridge = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/fridge
          home-manager.nixosModules.home-manager
          (common ./home/profiles/linux.nix)
        ];
      };

      # standalone home-manager for clusters without root. see ./setup
      homeConfigurations.cluster = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
        modules = [
          ./home
          ./home/profiles/cluster.nix
        ];
      };
    };
}
