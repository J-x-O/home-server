{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.uptime-kuma;
in
{
  options.homelab.uptime-kuma = {
    enable = lib.mkEnableOption "Uptime Kuma service monitoring";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings = {
        # Reachable from the LAN until there's a reverse proxy in front.
        HOST = "0.0.0.0";
        PORT = toString cfg.port;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # DynamicUser makes /var/lib/uptime-kuma a symlink; back up the real directory,
    # plus a consistent snapshot of the live SQLite database.
    homelab.backup = {
      paths = [ "/var/lib/private/uptime-kuma" ];
      exclude = [ "/var/lib/private/uptime-kuma/kuma.db*" ];
      prepareCommands = ''
        if [ -f /var/lib/private/uptime-kuma/kuma.db ]; then
          ${lib.getExe pkgs.sqlite} /var/lib/private/uptime-kuma/kuma.db ".backup '/var/backup/uptime-kuma.db'"
        fi
      '';
    };
  };
}
