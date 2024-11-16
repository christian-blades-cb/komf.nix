{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.komf;
  inherit (lib) mkOption mkEnableOption mkPackageOption;
  inherit (lib.types) port str bool;
  defaultConfigs = {
    database.file = "${cfg.stateDir}/database.yml";
  };
  applicationFormat = pkgs.formats.yaml { };
  applicationYml = applicationFormat.generate "application.yml" (defaultConfigs // cfg.settings);
in

{
  # TODO: other credentials (kavita, comicvine) as LoadCredential files
  options = {
    services.komf = with lib; {
      enable = mkEnableOption "Komga and Kavita metadata fetcher";

      port = mkOption {
        type = port;
        default = 8085;
        description = "The port that Komf will listen on.";
      };

      user = mkOption {
        type = str;
        default = "komf";
        description = "User account under which Komf runs.";
      };

      group = mkOption {
        type = str;
        default = "komf";
        description = "Group under which Komf runs.";
      };

      stateDir = mkOption {
        type = str;
        default = "/var/lib/komf";
        description = "State and configuration directory Komf will use.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.callPackage ./default.nix {};
        description = "Komf package to use";
      };

      openFirewall = mkOption {
        type = bool;
        default = false;
        description = "Whether to open the firewall for the port in {option}`services.komf.port`.";
      };

      settings = mkOption {
        type = applicationFormat.type;
        default = { };
        description = "Komf settings (application.yml). See https://github.com/Snd-R/komf?tab=readme-ov-file#example-applicationyml-config";
      };

      komga = {
        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the password for komga user";
          example = "/run/agenix/komga-creds";
        };
        
        user = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Komga username";
          example = "admin";
        };
        
        uri = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Komga base URI";
          example = "https://komga.company:1313";
        };
      };

    };
  };

  config =
    let
      inherit (lib) mkIf getExe;
      komgaEnabled = with cfg.komga; (passwordFile != null) && (user != null) && (uri != null);
    in

    mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
      users.groups = mkIf (cfg.group == "komf") { komf = { }; };
      users.users = mkIf (cfg.user == "komf") {
        komf = {
          group = cfg.group;
          home = cfg.stateDir;
          description = "Komf Daemon user";
          isSystemUser = true;
        };
      };

      systemd.services.komf = {
        environment = {
          KOMF_SERVER_PORT = builtins.toString cfg.port;
        } // lib.optionalAttrs komgaEnabled {
          KOMF_KOMGA_BASE_URI = cfg.komga.uri;
          KOMF_KOMGA_USER = cfg.komga.user;
        };

        description = "Komf is a free and open source comics/mangas media server";

        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;

          Type = "simple";
          Restart = "on-failure";
          ExecStart = "${getExe cfg.package} ${applicationYml}";

          LoadCredential = lib.optionalString (cfg.komga.passwordFile != null) "KOMF_KOMGA_PASSWORD:${cfg.komga.passwordFile}";

          StateDirectory = mkIf (cfg.stateDir == "/var/lib/komf") "komf";

          RemoveIPC = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          SystemCallFilter = [ "@system-service" ];
          ProtectSystem = "full";
          PrivateTmp = true;
          ProtectProc = "invisible";
          ProtectClock = true;
          ProcSubset = "pid";
          PrivateUsers = true;
          PrivateDevices = true;
          ProtectHostname = true;
          ProtectKernelTunables = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];

          LockPersonality = true;
          RestrictNamespaces = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectKernelModules = true;
          SystemCallArchitectures = "native";
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
        };
      };
    };
}
