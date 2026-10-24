# Nightly restic backups to a Hetzner Storage Box.
#
# Service modules contribute what they need backed up:
#   homelab.backup.paths = [ "/var/lib/foo" ];
#   homelab.backup.prepareCommands = "pg_dump foo > /var/backup/foo.sql";
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.homelab.backup;
  secrets = config.sops.secrets;
in
{
  options.homelab.backup = {
    enable = lib.mkEnableOption "restic backups to a Hetzner Storage Box";

    storageBox = {
      user = lib.mkOption {
        type = lib.types.str;
        example = "u123456";
        description = "Storage Box username.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.storageBox.user}.your-storagebox.de";
        defaultText = lib.literalExpression ''"''${user}.your-storagebox.de"'';
        description = "Storage Box hostname.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        # Port 23 is the full OpenSSH service; port 22 is a limited SFTP-only server.
        default = 23;
      };
      hostKey = lib.mkOption {
        type = lib.types.str;
        example = "ssh-ed25519 AAAA...";
        description = "Storage Box SSH host key, from `ssh-keyscan -t ed25519 -p 23 <host>`.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "restic/${config.networking.hostName}";
        description = "Repository path, relative to the Storage Box home directory.";
      };
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths to back up.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Patterns to exclude, e.g. regenerable thumbnails and caches.";
    };

    prepareCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Commands run before each backup, e.g. database dumps into /var/backup.";
    };

    pushMonitor.enable = lib.mkEnableOption ''
      pinging an Uptime Kuma push monitor after each successful backup.
      The push URL is read from the `restic/kuma-push-url` secret'';
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      "restic/password" = { };
      "restic/storagebox-ssh-key" = { };
    }
    // lib.optionalAttrs cfg.pushMonitor.enable {
      "restic/kuma-push-url" = { };
    };

    programs.ssh.extraConfig = ''
      Host storagebox
        HostName ${cfg.storageBox.host}
        User ${cfg.storageBox.user}
        Port ${toString cfg.storageBox.port}
        IdentityFile ${secrets."restic/storagebox-ssh-key".path}
        IdentitiesOnly yes
    '';

    programs.ssh.knownHosts.storagebox = {
      hostNames = [ "[${cfg.storageBox.host}]:${toString cfg.storageBox.port}" ];
      publicKey = cfg.storageBox.hostKey;
    };

    # Staging area for database dumps.
    systemd.tmpfiles.rules = [ "d /var/backup 0700 root root -" ];
    homelab.backup.paths = [ "/var/backup" ];

    services.restic.backups.storagebox = {
      initialize = true;
      repository = "sftp:storagebox:${cfg.storageBox.path}";
      passwordFile = secrets."restic/password".path;
      inherit (cfg) paths exclude;
      backupPrepareCommand = cfg.prepareCommands;

      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 2"
      ];
    };

    # Only ping on success: a failed or skipped run then shows up as "down"
    # in Uptime Kuma once the heartbeat interval passes.
    systemd.services = lib.mkIf cfg.pushMonitor.enable {
      restic-backups-storagebox.unitConfig.OnSuccess = [ "restic-backups-storagebox-ping.service" ];

      restic-backups-storagebox-ping = {
        description = "Report successful restic backup to Uptime Kuma";
        serviceConfig.Type = "oneshot";
        script = ''
          ${lib.getExe pkgs.curl} -fsS --retry 3 "$(cat ${secrets."restic/kuma-push-url".path})"
        '';
      };
    };
  };
}
