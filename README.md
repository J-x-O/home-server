# home-server

NixOS flake for the home server.

| Path | Purpose |
|---|---|
| `hosts/homeserver/` | Host config (hardware, users, SSH, which `homelab.*` modules are enabled) |
| `modules/backup.nix` | Nightly restic backup to a Hetzner Storage Box, 7d/4w/12m/2y retention |
| `modules/uptime-kuma.nix` | Uptime Kuma on port 3001 |
| `secrets/secrets.yaml` | sops-encrypted secrets (create it, see below) |

Planned: CouchDB (Obsidian LiveSync), Claude Code vault automations, Home Assistant, Immich, Paperless-ngx.
Each service module adds its data to `homelab.backup.paths` / `prepareCommands`.

## First-time setup

1. **Install**: boot the NixOS minimal ISO, get internet, then
   ```sh
   sudo -i
   bash <(curl -sL https://raw.githubusercontent.com/J-x-O/home-server/main/install.sh)
   ```
   The script handles UEFI and legacy BIOS (the Y50 only boots legacy).
   After reboot: log in on the console, join Wi-Fi with `nmtui`, then copy the generated
   configs back and commit them:
   `scp jesco@<ip>:/etc/nixos/hosts/homeserver/{hardware-configuration,bootloader}.nix hosts/homeserver/`
   Backups stay disabled until `secrets/secrets.yaml` exists (steps 2–4).

2. **Storage Box**: in the Hetzner console, enable SSH support and set the username in
   `homelab.backup.storageBox.user`. Create a key for the server and install it on the box:
   ```sh
   ssh-keygen -t ed25519 -N "" -f storagebox_key
   cat storagebox_key.pub | ssh -p 23 uXXXXXX@uXXXXXX.your-storagebox.de install-ssh-key
   ```

3. **sops keys**: put your age public key and the server's key into `.sops.yaml`:
   ```sh
   age-keygen -o ~/.config/sops/age/keys.txt         # your key (once)
   ssh-keyscan -t ed25519 <server> | ssh-to-age      # server key
   ```

4. **Secrets**: `sops secrets/secrets.yaml` and fill in:
   ```yaml
   restic:
     password: <long random string>   # e.g. `openssl rand -base64 48`
     storagebox-ssh-key: |
       <contents of storagebox_key>
   ```
   **Store the restic password outside the server too** (password manager). Without it the backup is unreadable.
   Then delete the local `storagebox_key*` files.

5. **Deploy** from your desktop:
   ```sh
   nixos-rebuild switch --flake .#homeserver --target-host jesco@<server> --sudo
   ```

6. **Backup monitoring**: in Uptime Kuma (`http://<server>:3001`) add a *Push* monitor with a
   heartbeat interval of ~25h. Add its URL as `restic.kuma-push-url` in the secrets
   (use `http://127.0.0.1:3001/api/push/<token>?status=up&msg=OK`), set
   `homelab.backup.pushMonitor.enable = true`, and redeploy.

## Everyday commands (on the server)

```sh
sudo systemctl start restic-backups-storagebox   # run a backup now
journalctl -u restic-backups-storagebox          # logs
sudo restic-storagebox snapshots                 # list snapshots
sudo restic-storagebox restore latest --target /tmp/restore --include /var/backup
```

Test a restore every now and then.
