# HTTPS for every dashboard app at https://<subdomain>.<homelab.domain>, with the
# start page on the domain itself. Caddy gets the certificates from Let's Encrypt
# via the DNS challenge, so the server never has to be reachable from the internet.
#
# The challenge is delegated so the server holds no key for the main DNS zone:
#   _acme-challenge.<domain>  CNAME  <challengeDomain>   (at IONOS)
#   <challengeDomain>         TXT    written by Caddy    (at deSEC)
# The deSEC token (`desec/token`) is scoped to that single TXT record.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.homelab) domain;
  cfg = config.homelab.https;
  apps = lib.attrValues config.homelab.dashboard.apps;

  route = app: ''
    @${app.subdomain} host ${app.subdomain}.${domain}
    handle @${app.subdomain} {
      reverse_proxy 127.0.0.1:${toString app.port}
    }
  '';
in
{
  options.homelab.https.challengeDomain = lib.mkOption {
    type = lib.types.str;
    example = "_acme-challenge.acme.example.com";
    description = "Name in a deSEC zone that `_acme-challenge.<domain>` is a CNAME to.";
  };

  config = lib.mkIf (domain != null) {
    sops.secrets."desec/token" = { };
    sops.templates."caddy.env" = {
      content = "DESEC_TOKEN=${config.sops.placeholder."desec/token"}";
      owner = config.services.caddy.user;
    };

    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/desec@v1.1.0" ];
        hash = "sha256-HrLRezw+q5+dRdJS662686n7xsImSxNb3UqlSo61R8E=";
      };
      environmentFile = config.sops.templates."caddy.env".path;

      # A wildcard certificate keeps the app names out of the public certificate logs.
      virtualHosts."${domain}, *.${domain}".extraConfig = ''
        tls {
          dns desec {
            token {env.DESEC_TOKEN}
          }
          dns_challenge_override_domain ${cfg.challengeDomain}
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
