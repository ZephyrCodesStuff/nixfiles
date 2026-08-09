{ config, pkgs, lib, ... }:

{
  # 1. Enable IOMMU and VFIO kernel parameters
  boot.kernelParams = [
    "intel_iommu=on" # Use "amd_iommu=on" if on an AMD CPU
    "iommu=pt"
  ];

  # Raise security ulimits for locked memory
  security.pam.loginLimits = [
    { domain = "*"; item = "memlock"; type = "soft"; value = "unlimited"; }
    { domain = "*"; item = "memlock"; type = "hard"; value = "unlimited"; }
  ];

  # Instruct systemd to give libvirtd unlimited memory locking
  systemd.services.libvirtd.serviceConfig = {
    LimitMEMLOCK = "infinity";
  };

  # Virtualization & QEMU / Libvirt service configuration
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      verbatimConfig = ''
	user = "root"
        group = "root"
        cgroup_controllers = [ "cpu", "devices", "memory", "blkio", "cpuset", "cpuacct" ]
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
          "/dev/rtc", "/dev/hpet", "/dev/vfio/vfio",
          "/dev/vfio/15"
        ]
      '';
      swtpm.enable = true; # Emulated TPM 2.0 for Windows 11
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm", MODE="0660"
  '';

  # KVM and VFIO management packages
  environment.systemPackages = with pkgs; [
    virt-manager         # GUI management interface
    virt-viewer          # Display console
    virtio-win # Windows VirtIO drivers ISO
    looking-glass-client # Low-latency video streaming client from KVM to host
  ];
}
