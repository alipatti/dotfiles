{
  description = "ali's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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
    { nix-darwin, home-manager, ... }:
    {
      # sudo darwin-rebuild switch --flake ~/.dotfiles
      darwinConfigurations."MacBook-Air" = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # move files home-manager wants to own out of the way instead of failing
            home-manager.backupFileExtension = "bak";
            home-manager.users.ali.imports = [
              ./home
              ./home/darwin.nix
            ];
          }
        ];
      };
    };
}
