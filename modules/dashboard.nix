# Start page at http://<host>/ listing every app that registers itself:
#   homelab.dashboard.apps.Immich = { group = "Media"; port = 2283; ... };
{ config, lib, ... }:

let
  cfg = config.homelab.dashboard;
  inherit (config.homelab) domain;
  host = lib.head config.homelab.hostNames;
  port = config.services.homepage-dashboard.listenPort;

  groups = lib.unique (lib.mapAttrsToList (_: app: app.group) cfg.apps);
  appsIn = group: lib.filterAttrs (_: app: app.group == group) cfg.apps;
  tile = name: app: {
    ${name} = {
      inherit (app) description icon;
      href =
        if domain != null then "https://${app.subdomain}.${domain}" else "http://${host}:${toString app.port}";
      siteMonitor = "http://127.0.0.1:${toString app.port}";
    };
  };
in
{
  options.homelab.dashboard = {
    enable = lib.mkEnableOption "the Homepage start page on port 80";

    apps = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            group = lib.mkOption { type = lib.types.str; };
            port = lib.mkOption { type = lib.types.port; };
            subdomain = lib.mkOption {
              type = lib.types.str;
              description = "Served at `<subdomain>.<homelab.domain>` when a domain is set.";
            };
            description = lib.mkOption { type = lib.types.str; };
            icon = lib.mkOption {
              type = lib.types.str;
              description = "Icon name from https://github.com/homarr-labs/dashboard-icons, e.g. `immich.png`.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      allowedHosts = lib.concatStringsSep "," (
        config.homelab.hostNames
        ++ lib.optional (domain != null) domain
        ++ [ "localhost:${toString port}" "127.0.0.1:${toString port}" ]
      );
      settings.title = "Homeserver";
      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
      ];
      services = map (group: { ${group} = lib.mapAttrsToList tile (appsIn group); }) groups;
    };

    # Serve it on plain port 80 so http://homeserver works without a port.
    services.caddy = {
      enable = true;
      virtualHosts.":80".extraConfig = "reverse_proxy 127.0.0.1:${toString port}";
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
