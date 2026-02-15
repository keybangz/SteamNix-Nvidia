{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  services.xserver.videoDrivers = [
        "modesetting"
        "nvidia"
  ];

  hardware.graphics.enable = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;
  hardware.nvidia.open = true;
  hardware.nvidia.powerManagement.enable = true;
  hardware.nvidia.forceFullCompositionPipeline = true;
  hardware.nvidia.modesetting.enable = true;

  hardware.nvidia.prime = {
    # nix shell nixpkgs#pciutils -c lspci -D -d ::03xx
    # https://wiki.nixos.org/wiki/NVIDIA // Conversion required
    intelBusId = "PCI:0@0:2:0";
    nvidiaBusId = "PCI:1@0:0:0";
  };

  specialisation.laptop-mode.configuration = {
    system.nixos.tags = [ "laptop-mode" ];
    hardware.nvidia.powerManagement.finegrained = true;

    hardware.nvidia.prime = {
      offload = {
        enable = lib.mkForce true;
        enableOffloadCmd = lib.mkForce true;
      };

      sync.enable = lib.mkForce false;
    };
  };

  specialisation.tv-mode.configuration = {
    system.nixos.tags = [ "tv-mode" ];
    boot.kernelParams = [ "module_blacklist=i915" ];
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;

    hardware.nvidia.prime = {
      offload.enable = lib.mkForce false;
      sync.enable = lib.mkForce true;
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree         = true;

  ####################
  # Boot & Kernel    #
  ####################
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout                  = 5;
  boot.loader.systemd-boot.configurationLimit    = 2;
  hardware.amdgpu.initrd.enable = false;

  boot.kernelParams = [ "quiet" "nvidia.NVreg_TemporaryFilePath=/var/tmp" ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
    "kernel.nmi_watchdog"        = 0;
    # "kernel.sched_bore"          = "1";
  };

  boot.initrd = {
    systemd.enable   = true;
    # kernelModules    = [ ];
    verbose          = false;
  };
  boot.plymouth.enable     = true;
  boot.consoleLogLevel     = 0;
  systemd.settings.Manager = {DefaultTimeoutStopSec="5s";};

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
    alsa.enable    = true;
    alsa.support32Bit = true;
    pulse.enable   = true;
  };

  ########################
  # Graphical & Jovian   #
  ########################
  services.xserver.enable            = false;
  #services.logind.extraConfig = ''HandlePowerKey=poweroff''; #set power button to shutdown on press
  jovian = {
    steam.enable = true;
    steam.autoStart = true;
    steam.user = "steamos";
    hardware.has.amd.gpu = false;
    decky-loader.enable = true;
    decky-loader.user = "steamos";
    steamos.useSteamOSConfig = false;
    steam.desktopSession = "cosmic";
    devices.steamdeck.enableVendorDrivers = false;
  };


  ########################
  # Programs & Services    #
  ########################
  services.automatic-timezoned.enable = true;
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  services.desktopManager.cosmic.enable = true;
  services.flatpak.enable = true;
  services.resolved.enable         = true;
  services.avahi.enable            = true;
  services.avahi.nssmdns           = true;

  programs = {
    appimage = { enable = true; binfmt = true; };
    fish     = { enable = true; };
    mosh     = { enable = true; };
    tmux     = { enable = true; };
     };

  environment.sessionVariables = {
    PROTON_USE_NTSYNC       = "1";
    ENABLE_HDR_WSI          = "1";
    DXVK_HDR                = "1";
    # PROTON_ENABLE_AMD_AGS   = "1";
    PROTON_ENABLE_NVAPI     = "1";
    ENABLE_GAMESCOPE_WSI    = "1";
    STEAM_MULTIPLE_XWAYLANDS = "1";
  };

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
        git
        firefox-esr
        vacuum-tube
        discord
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
  system.stateVersion = "24.11";
}
