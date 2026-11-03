{ config, lib, ... }:

let
  cfg = config.homelab.paperless;
  port = toString config.services.paperless.port;
  inherit (config.homelab) domain;
  httpsHost = "docs.${domain}";
  # Django rejects logins from origins it doesn't know.
  origins =
    lib.optional (domain != null) "https://${httpsHost}"
    ++ map (host: "http://${host}:${port}") config.homelab.hostNames;
in
{
  options.homelab.paperless.enable = lib.mkEnableOption "Paperless-ngx document management";

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      settings = {
        PAPERLESS_URL = lib.head origins;
        PAPERLESS_CSRF_TRUSTED_ORIGINS = lib.concatStringsSep "," origins;
        # localhost for the dashboard's status check.
        PAPERLESS_ALLOWED_HOSTS = lib.concatStringsSep "," (
          config.homelab.hostNames ++ lib.optional (domain != null) httpsHost ++ [ "127.0.0.1" ]
        );
        PAPERLESS_OCR_LANGUAGE = "deu+eng";
        PAPERLESS_TIME_ZONE = config.time.timeZone;
      };
    };

    networking.firewall.allowedTCPPorts = [ config.services.paperless.port ];

    homelab.dashboard.apps.Paperless = {
      group = "Documents";
      port = config.services.paperless.port;
      description = "Scanned documents and letters";
      icon = "paperless-ngx.png";
      subdomain = "docs";
    };

    # The exporter writes a consistent, restorable copy of documents and database.
    homelab.backup = {
      paths = [ "/var/backup/paperless" ];
      prepareCommands = ''
        ${lib.getExe' config.services.paperless.manage "paperless-manage"} document_exporter /var/backup/paperless --no-progress-bar
      '';
    };
  };
}
