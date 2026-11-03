# HTTPS for every dashboard app at https://<subdomain>.<homelab.domain>, with the
# start page on the domain itself. Caddy gets the certificates from Let's Encrypt
# via the DNS challenge, using the IONOS API key from sops (`ionos/api-key`), so
# the server never has to be reachable from the internet.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.homelab) domain;
  apps = lib.attrValues config.homelab.dashboard.apps;

  route = app: ''
    @${app.subdomain} host ${app.subdomain}.${domain}
    handle @${app.subdomain} {
      reverse_proxy 127.0.0.1:${toString app.port}
    }
  '';
in
{
  config = lib.mkIf (domain != null) {
    sops.secrets."ionos/api-key" = { };
    sops.templates."caddy.env" = {
      content = "IONOS_API_TOKEN=${config.sops.placeholder."ionos/api-key"}";
      owner = config.services.caddy.user;
    };

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/ionos@v1.3.0" ];
        hash = "sha256-tUup77YI8MxlOLE+yBUP5Ya0T6NDWlHq6ykcQM5Zv64=";
      };
      environmentFile = config.sops.templates."caddy.env".path;

      # A wildcard certificate keeps the app names out of the public certificate logs.
      virtualHosts."${domain}, *.${domain}".extraConfig = ''
        tls {
          dns ionos {env.IONOS_API_TOKEN}
        }

        ${lib.concatMapStrings route apps}
        handle {
          reverse_proxy 127.0.0.1:${toString config.services.homepage-dashboard.listenPort}
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
