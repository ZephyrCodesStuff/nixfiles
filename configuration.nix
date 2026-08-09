{ config, pkgs, lib, inputs, ... }: {
  # 0. Enable unfree drivers (for NVIDIA proprietary)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.helium.overlays.default
  ];

  # 1. Enforce systemd-native initrd (Replaces legacy initrd scripts)
  boot.initrd.systemd.enable = true;

  # 2. Configure LUKS2 Unlocking via systemd-cryptsetup
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/b1c4e867-6239-48e9-b85b-d4cd1b6869a7";
    crypttabExtraOpts = [ "tpm2-device=auto" ];
    allowDiscards = true;
  };

  # 3. Enable Lanzaboote (Disables systemd-boot in favor of signed UKIs)
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # 4. Enable TPM2 daemon in systemd
  security.tpm2.enable = true;

  system.stateVersion = "26.11";

  # ---- Actual system config (user mode) ----
  users.users.zeph = {
    isNormalUser = true;
    description = "zeph";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "docker" ];
    shell = pkgs.fish;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Enable Fish shell globally so vendor integrations work
  programs.fish.enable = true;

  # --- GRAPHICAL ENVIRONMENT (i3 + Picom + Portals) ---
  services.xserver = {
    enable = true;
    layout = "gb"; # Adjust to your keyboard layout (e.g., "it")
    videoDrivers = [ "nvidia" ];
    
    displayManager.defaultSession = "none+i3";
    displayManager.lightdm = {
      enable = true;
      greeters.slick.enable = true;
    };
    displayManager.autoLogin = {
      enable = true;
      user = "zeph";
    };
    displayManager.setupCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --output DP-0 --mode 1920x1080 --rate 144
    '';
    
    desktopManager.xterm.enable = false;

    windowManager.i3 = {
      enable = true;
      package = pkgs.i3;
      extraPackages = with pkgs; [
        dmenu           # Application launcher (or rofi)
        i3status        # Default status bar
        i3lock          # Screen locker
      ];
    };
  };

  # Compositor to prevent screen tearing and fix window transparency/shadows
  services.picom = {
    enable = true;
    backend = "glx"; # GPU acceleration
    vSync = true;
    shadow = true;
    fade = true;
    fadeDelta = 4;
  };

  # XDG Desktop Portals (Required for screensharing, file pickers, and screen capture)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # --- AUDIO (PipeWire for low-latency DSP & screenshare audio) ---
  security.rtkit.enable = true;
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # --- HARDENED SSH ARCHITECTURE ---
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  # PC/SC Daemon for YubiKey / FIDO2 Hardware Keys (if used)
  services.pcscd.enable = true;

  # Enable SSH Agent globally (or use GNOME Keyring / KeePassXC)
  programs.ssh.startAgent = true;

  # --- SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    # Secure Boot utilities
    sbctl           # Secure Boot key manager
    tpm2-tools      # TPM2 inspection

    # Core utilities
    git
    curl
    wget
    alacritty       # High-performance terminal emulator
    neovim
    
    # Desktop utilities & Screenshots
    feh             # Wallpaper setter / image viewer
    maim            # Screenshot utility
    xclip           # Clipboard manager for maim/X11
    helium  	    # Helium browser (helium.computer)
    firefox         # For everything Helium can't to (DRM)
    
    # Discord / Communication
    vesktop         # Optimized Discord client with working Wayland/X11 screenshare + audio
    
    # Development tools
    vscodium
    ccache
    gdb
    cmake
    ninja
    docker-compose

    # Audio utils
    pavucontrol   # GUI volume control for PipeWire / Pulse
    alsa-utils    # Provides alsamixer, amixer, speaker-test
    pulsemixer    # Terminal UI volume mixer
  ];

  # Enable 32-bit graphics drivers (essential for RPCS3 / Wine / Vulkan testing)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;

    open = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  
  # Patch AppImages to run with `appimage-run`
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
