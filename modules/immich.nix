{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.immich;
  media = config.services.immich.mediaLocation;
in
{
  options.homelab.immich.enable = lib.mkEnableOption "Immich photo library";

  config = lib.mkIf cfg.enable {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
    };

    homelab.dashboard.apps.Immich = {
      group = "Media";
      port = config.services.immich.port;
      description = "Photos and videos";
      icon = "immich.png";
    };

    homelab.backup = {
      paths = [ media ];
      # Thumbnails and transcoded videos are regenerated from the originals.
      exclude = [
        "${media}/thumbs"
        "${media}/encoded-video"
      ];
      prepareCommands = ''
        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/pg_dump ${config.services.immich.database.name} \
          > /var/backup/immich.sql
      '';
    };
  };
}
