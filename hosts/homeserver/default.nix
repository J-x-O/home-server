{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./bootloader.nix
    ../../modules
  ];

  networking.hostName = "homeserver";
  # Wi-Fi was joined once with `nmtui`; NetworkManager keeps the profile in /etc/NetworkManager.
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Berlin";


  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users.jesco = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEbov1bdOCO8xnq84poRsE6Xa71vQnfblcoxn685GaoJ jesco@tower"
    ];
  };

  # Login is key-only, so there is no password to type for sudo.
  security.sudo.wheelNeedsPassword = false;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Allows `nixos-rebuild --target-host` deploys from your desktop.
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  homelab.backup = {
    # The secrets file can only be created after the first install (it needs the
    # server's host key), so backups switch on once it exists.
    enable = builtins.pathExists ../../secrets/secrets.yaml;
    storageBox = {
      user = "u699594";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
    };
    # Enable once the Uptime Kuma push monitor exists (see README).
    pushMonitor.enable = false;
  };

  homelab.uptime-kuma.enable = true;

  # Don't change this after the first install, even when upgrading NixOS.
  system.stateVersion = "26.05";
}
