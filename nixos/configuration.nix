# see `nixos-help`

{ pkgs, ... }:

{
  imports = [
    # include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
    ./nas.nix
  ];

  # bootloader (don't touch these)
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  # networking
  networking.hostName = "fridge";
  networking.networkmanager.enable = true;

  # ssh
  services.openssh = {
    enable = true;
    ports = [ 8191 ];
    settings = {
      PasswordAuthentication = false; # ssh keypairs only
      PermitRootLogin = "no";
    };
  };

  # tailscale
  services.tailscale.enable = true;

  # TODO: setup nginx reverse proxy

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # graphics
  nixpkgs.config.allowUnfree = true; # allow non open source
  hardware.graphics.enable = true; # use hardware graphics card
  hardware.nvidia = {
    open = true; # recommended for Turing onwards
    powerManagement.enable = true; # fixes broken graphics after sleep
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # gdm/gnome
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];

  # misc
  programs.nix-ld.enable = true; # needed for uv
  programs.fish.enable = true;
  virtualisation.docker.enable = true;

  # packages
  environment.systemPackages = with pkgs; [
    # gui apps
    nautilus # files
    firefox # browser
    kitty # terminal
    prismlauncher
    spotify
    slack

    # git
    git
    git-crypt
    git-lfs
    gh

    # cli tools
    zoxide
    starship
    eza
    ripgrep
    nix-your-shell # use fish by default for nix-shell etc.
    trashy

    # editor
    neovim
    claude-code
    tree-sitter

    # language tooling
    rustup
    gcc
    uv
  ];

  users.users.ali = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager" # allow network config
      "wheel" # allow sudo
      "docker"
    ];
  };
  
  # env vars
  environment.sessionVariables = {
    BROWSER = "firefox";
  };

  # fonts
  fonts.packages = with pkgs; [
    nerd-fonts.cousine
  ];

  system.stateVersion = "25.11"; # don't change this line
}
