# home-server

NixOS flake for the home server.

| Path | Purpose |
|---|---|
| `hosts/homeserver/` | Host config (hardware, users, SSH, which `homelab.*` modules are enabled) |
| `modules/backup.nix` | Nightly restic backup to a Hetzner Storage Box, 7d/4w/12m/2y retention |
| `modules/dashboard.nix` | Homepage start page on port 80; every service adds its own tile |
| `modules/https.nix` | Caddy: Let's Encrypt via the DNS challenge, one name per app |
| `modules/{immich,paperless,home-assistant,uptime-kuma}.nix` | The services themselves |
| `scripts/set-secret.sh` | Stores a secret in `secrets/secrets.yaml` without writing it to disk |
| `secrets/secrets.yaml` | sops-encrypted secrets |

Still to come: CouchDB (Obsidian LiveSync) and Claude Code automations on the vault.

Each service module registers what it needs: `homelab.backup.paths` / `prepareCommands`
for backups and `homelab.dashboard.apps` for its tile and subdomain.

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

4. **Secrets**: write them without exposing them:
   ```sh
   nix shell nixpkgs#sops nixpkgs#jq -c ./scripts/set-secret.sh restic/password
   nix shell nixpkgs#sops nixpkgs#jq -c ./scripts/set-secret.sh restic/storagebox-ssh-key
   ```
   **Store the restic password outside the server too** (password manager). Without it the backup is unreadable.
   Then delete the local `storagebox_key*` files.

5. **Deploy** from your desktop:
   ```sh
   nixos-rebuild switch --flake .#homeserver --target-host jesco@<server> --build-host jesco@<server> --sudo
   ```

6. **Backup monitoring**: in Uptime Kuma (`http://<server>:3001`) add a *Push* monitor with a
   heartbeat interval of ~25h. Add its URL as `restic/kuma-push-url` in the secrets
   (use `http://127.0.0.1:3001/api/push/<token>?status=up&msg=OK`), set
   `homelab.backup.pushMonitor.enable = true`, and redeploy.

## HTTPS

`homelab.domain` = `home.jesco.dev`, served with a Let's Encrypt certificate for the apex
and `*.home.jesco.dev`. The start page is on the domain, each app on its own subdomain
(`photos`, `docs`, `ha`, `status`).

The certificate is obtained with the **DNS challenge**, delegated so the server holds no key
for the main zone:

| Where | Record | Purpose |
|---|---|---|
| IONOS | `A home` / `A *.home` → `192.168.178.40` | the names (LAN-only address) |
| IONOS | `CNAME _acme-challenge.home` → `_acme-challenge.acme.jesco.dev` | hands the challenge to deSEC |
| IONOS | `NS acme` → deSEC nameservers | deSEC hosts the `acme.jesco.dev` zone |
| deSEC | `TXT _acme-challenge.acme.jesco.dev` | written and removed by Caddy |

The deSEC token (`desec/token`) may only write that single TXT record, so a leaked token
cannot change any A records. Renewal is automatic, ~60 days ahead of expiry.

**The FRITZ!Box needs one exception**: *Heimnetz → Netzwerk → Netzwerkeinstellungen →
DNS-Rebind-Schutz → Hostnamen-Ausnahmen*: `home.jesco.dev`. Without it the router refuses
public names that point into the LAN.

## Troubleshooting

**Home Assistant answers 400 "request from a reverse proxy"** — since 2026.10 HA keeps the
web server settings in `/var/lib/hass/.storage/http`; a changed `http:` block lands in
`.data.pending` and is never promoted. Promote it and restart:
```sh
sudo systemctl stop home-assistant
sudo nix run nixpkgs#jq -- '.data.stable = .data.pending | .data.pending = null' \
  < <(sudo cat /var/lib/hass/.storage/http) | sudo tee /var/lib/hass/.storage/http.new > /dev/null
sudo chown --reference=/var/lib/hass/.storage/http /var/lib/hass/.storage/http.new
sudo mv /var/lib/hass/.storage/http.new /var/lib/hass/.storage/http
sudo systemctl start home-assistant
```

## Everyday commands (on the server)

```sh
sudo systemctl start restic-backups-storagebox   # run a backup now
journalctl -u restic-backups-storagebox          # logs
sudo restic-storagebox snapshots                 # list snapshots
sudo restic-storagebox restore latest --target /tmp/restore --include /var/backup
```

Test a restore every now and then.
