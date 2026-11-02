{ lib, ... }:

{
  options.homelab.hostNames = lib.mkOption {
    type = lib.types.nonEmptyListOf lib.types.str;
    example = [
      "homeserver"
      "homeserver.fritz.box"
      "192.168.178.40"
    ];
    description = ''
      Names the server is reached by on the LAN. The first one is used for links
      on the dashboard; all of them are accepted by apps that check the Host header.
    '';
  };
}
