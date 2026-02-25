{ config, pkgs, inputs, lib, ... }:

{
  imports =
  [ # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config = {
    allowUnfree = true;
  };

  services.xserver.videoDrivers = [
        "nvidia"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; 
  };

  environment.variables.LIBVA_DRIVER_NAME = "nvidia";

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = lib.mkDefault false;
    dynamicBoost.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    forceFullCompositionPipeline = false;
  };

  boot.kernelModules = ["nvidia_uvm" "nvidia_modeset" "nvidia_drm" "nvidia"];

  hardware.nvidia.prime = {
    offload.enable = false;
    sync.enable = true;

    # nix shell nixpkgs#pciutils -c lspci -D -d ::03xx
    # https://wiki.nixos.org/wiki/NVIDIA // Conversion required
    intelBusId = "PCI:0@0:2:0";
    nvidiaBusId = "PCI:1@0:0:0";
  };

  specialisation.laptop-mode.configuration = {
    system.nixos.tags = [ "laptop-mode" ];
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" "nvidia" ];

    hardware.nvidia.powerManagement.finegrained = true;
    boot.kernelParams = lib.mkForce [ "quiet" "nvidia.NVreg_TemporaryFilePath=/var/tmp" ];

    hardware.nvidia.prime = {
      offload = {
        enable = lib.mkForce true;
        enableOffloadCmd = lib.mkForce true;
      };

      sync.enable = lib.mkForce false;
    };
  };


  ####################
  # Boot & Kernel    #
  ####################
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout                  = 5;
  boot.loader.systemd-boot.configurationLimit    = 2;

  boot.kernelParams = [ "quiet" "nvidia.NVreg_TemporaryFilePath=/var/tmp" "module_blacklist=i915" ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
    "kernel.nmi_watchdog"        = 0;
    # "kernel.sched_bore"          = "1";
  };

  boot.initrd = {
    systemd.enable   = true;
    verbose          = false;
  };
  boot.plymouth.enable     = true;
  boot.consoleLogLevel     = 0;
  systemd.settings.Manager = {DefaultTimeoutStopSec="5s";};

  systemd = {
    services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";
  };

  ################
  # FileSystems  #
  ################
  fileSystems."/" = {
    options = [ "compress=zstd" ];
  };

  ############
  # Network  #
  ############
  networking = {
    networkmanager.enable = true;
    firewall.enable       = false;
    hostName              = "nixos";
  };

  #################
  # Bluetooth     #
  #################
  hardware.bluetooth.enable = true;
  hardware.bluetooth.settings = {
    General = {
      MultiProfile     = "multiple";
      FastConnectable  = true;
    };
  };

  #################
  # Sound & RTKit #
  #################
  security.rtkit.enable = true;
  services.pipewire = {
    enable         = true;
    alsa.enable    = false;
    alsa.support32Bit = false;
    pulse.enable   = true;
  };

  ########################
  # Graphical & Jovian   #
  ########################
  services.xserver.enable            = true;

  jovian = {
    steam.enable = true;
    steam.autoStart = true;
    steam.user = "steamos";
    steam.desktopSession = "plasma";

    decky-loader.enable = true;
    decky-loader.user = "steamos";

    steamos.useSteamOSConfig = true;

    devices.steamdeck.enableVendorDrivers = false;
    hardware.has.amd.gpu = false;
  };

  # Create Steam CEF debugging file if it doesn't exist for Decky Loader. 
  systemd.services.steam-cef-debug = lib.mkIf config.jovian.decky-loader.enable {
    description = "Create Steam CEF debugging file";
    serviceConfig = {
      Type = "oneshot";
      User = config.jovian.steam.user;
      ExecStart = "/bin/sh -c 'mkdir -p ~/.steam/steam && [ ! -f ~/.steam/steam/.cef-enable-remote-debugging ] && touch ~/.steam/steam/.cef-enable-remote-debugging || true'";
    };
    wantedBy = [ "multi-user.target" ];
  };

  ########################
  # Programs & Services    #
  ########################
  services.automatic-timezoned.enable = true;
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.flatpak.enable = true;
  services.resolved.enable         = true;
  services.avahi.enable            = true;
  services.avahi.nssmdns           = true;

  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  programs = {
    git.enable = true;
    appimage.enable = true; 
    appimage.binfmt = true;
    tmux.enable = true;

    steam = {
      package = pkgs.steam.override {
        extraLibraries = pkgs: [ pkgs.libxcb ];
        extraPkgs =
          pkgs: with pkgs; [
            libxcursor
            libxi
            libxinerama
            libxscrnsaver
            libpng
            libpulseaudio
            libvorbis
            stdenv.cc.cc.lib
            libkrb5
            keyutils
            gamemode
          ];
      };

      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };
  };

  environment.systemPackages = with pkgs; [
    ffmpeg
    cmake
    steam-rom-manager
    python315
    pipx
    zenity
    mesa-demos
  ];

  # environment.sessionVariables = {
    # PROTON_USE_NTSYNC       = "1";
    # ENABLE_HDR_WSI          = "1";
    # DXVK_HDR                = "1";
    # PROTON_ENABLE_AMD_AGS   = "1";
    # PROTON_ENABLE_NVAPI     = "1";
    # ENABLE_GAMESCOPE_WSI    = "0";
    # STEAM_MULTIPLE_XWAYLANDS = "1";
  # };

  ###################
  # Virtualization  #
  ###################
  virtualisation.docker.enable      = true;
  virtualisation.docker.enableOnBoot = false;
  virtualisation.libvirtd.enable = true;

  ###############
  # Users       #
  ###############
  users.users.steamos = {
    isNormalUser = true;
    description  = "SteamOS user";
    extraGroups  = [ "networkmanager" "wheel" "docker" "video" "seat" "audio" "libvirtd"];
    password     = "steamos";
    packages = with pkgs; [
        firefox-esr
    ];
  };

  #################
  # Security      #
  #################
  security.sudo.wheelNeedsPassword = false;
  security.polkit.enable           = true;
  services.seatd.enable            = true;
  services.openssh.enable          = true;

  ######################
  ######################

  ########################
  # System State Version #
  ########################
  system.stateVersion = "25.11";
}
