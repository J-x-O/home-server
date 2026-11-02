{ config, lib, pkgs, ... }:

let
  cfg = config.homelab.home-assistant;
in
{
  options.homelab.home-assistant.enable = lib.mkEnableOption "Home Assistant";

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      # Components needed for the first-run onboarding in the web UI.
      extraComponents = [
        "default_config"
        "met"
        "esphome"
        "analytics"
        "google_translate"
        "radio_browser"
        "shopping_list"
        "isal"
      ];
      customComponents = [
        pkgs.home-assistant-custom-components.localtuya
      ];
      config = {
        default_config = { };
        # Lets integrations and automations be managed from the web UI.
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };

    # Home Assistant's default web port.
    networking.firewall.allowedTCPPorts = [ 8123 ];

    # The UI-managed includes above must exist or Home Assistant won't start.
    systemd.tmpfiles.rules = [
      "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
      "f ${config.services.home-assistant.configDir}/scenes.yaml 0644 hass hass"
      "f ${config.services.home-assistant.configDir}/scripts.yaml 0644 hass hass"
    ];

    homelab.backup = {
      paths = [ config.services.home-assistant.configDir ];
      # The recorder database is only history and is large; skip it.
      exclude = [ "${config.services.home-assistant.configDir}/home-assistant_v2.db*" ];
    };
  };
}
