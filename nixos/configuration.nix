# see `nixos-help`

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    /etc/nixos/hardware-configuration.nix
  ];

  # bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.config.allowUnfree = true; # allow non-OS software

  # networking
  networking.hostName = "fridge";
  networking.networkmanager.enable = true;

  # ssh
  services.openssh = {
    enable = true;
    ports = [ 8191 ]; # to reduce bot noise
    settings = {
      PasswordAuthentication = false; # ssh keypairs only for now
      PermitRootLogin = "no";
    };
  };
  services.fail2ban.enable = true;

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # graphics
  hardware.graphics.enable = true; # use hardware graphics card
  hardware.nvidia.open = false; # use closed-source nvidia drivers
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    excludePackages = with pkgs; [ xterm ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

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

  services.printing.enable = true;

  programs.nix-ld.enable = true; # needed for uv
  programs.fish.enable = true;

  users.users.ali = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager" # allow network config
      "wheel" # allow sudo
    ];
    packages = with pkgs; [
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
      nix-your-shell # use fish by default for nix-shell etc.trashy

      # editor
      neovim

      # language tooling
      rustup
      gcc
      uv
      node
    ];
  };

  # TODO: migrate to env/
  environment.sessionVariables = {
    TERMINAL = "kitty";
    EDITOR = "nvim";
    BROWSER = "firefox";
  };

  # fonts
  fonts.packages = with pkgs; [
    nerd-fonts.cousine
  ];

  system.stateVersion = "25.11"; # don't change this
}
