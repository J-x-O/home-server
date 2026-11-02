{ config, lib, ... }:

let
  cfg = config.homelab.paperless;
in
{
  options.homelab.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx document management";

    url = lib.mkOption {
      type = lib.types.str;
      example = "http://192.168.178.40:28981";
      description = "URL Paperless is opened at; Django rejects logins from other origins.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      settings = {
        PAPERLESS_URL = cfg.url;
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = config.time.timeZone;
      };
    };

    networking.firewall.allowedTCPPorts = [ config.services.paperless.port ];

    # The exporter writes a consistent, restorable copy of documents and database.
    homelab.backup = {
      paths = [ "/var/backup/paperless" ];
      prepareCommands = ''
        ${lib.getExe' config.services.paperless.manage "paperless-manage"} document_exporter /var/backup/paperless --no-progress-bar
      '';
    };
  };
}
