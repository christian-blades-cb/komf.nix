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
    database.file = "${cfg.stateDir}/database.sqlite";
  };
  applicationFormat = pkgs.formats.yaml { };
  applicationYml = applicationFormat.generate "application.yml" (defaultConfigs // cfg.settings);
in

{
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

      kavita = {
        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the API key for the kavita instance";
          example = "/run/agenic/kavita-creds";
        };

        uri = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Kavita base url";
          example = "https://kavita.company:5000";
        };
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

      providers = {
        mal.passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the myanimelist client id";
          example = "/run/agenix/mal-clientid";
        };

        comicvine.passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the API key for comicvine";
          example = "/run/agenix/comicvine-apikey";
        };

        bangumi.passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "File containing the token for bangumi";
          example = "/run/agenix/bangumi-token";
        };
      };
    };
  };

  config =
    let
      inherit (lib) mkIf getExe;
      komgaEnabled = with cfg.komga; (passwordFile != null) && (user != null) && (uri != null);
      kavitaEnabled = with cfg.kavita; (passwordFile != null) && (uri != null);
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
        } // lib.optionalAttrs kavitaEnabled {
          KOMF_KAVITA_BASE_URI = cfg.kavita.uri;
        };

        # preStart =
        #     lib.optionalString (cfg.komga.passwordFile != null) ''
        #       export KOMF_KOMGA_PASSWORD=$(cat $CREDENTIALS_DIRECTORY/komf-komga-creds);
        #     ''
        #     + lib.optionalString (cfg.kavita.passwordFile != null) ''
        #       export KOMF_KAVITA_API_KEY=$(cat $CREDENTIALS_DIRECTORY/komf-kavita-creds);
        #     ''
        #     + lib.optionalString (cfg.providers.mal.passwordFile != null) ''
        #       export KOMF_METADATA_PROVIDERS_MAL_CLIENT_ID=$(cat $CREDENTIALS_DIRECTORY/komf-mal-creds);
        #     ''
        #     + lib.optionalString (cfg.providers.comicvine.passwordFile != null) ''
        #       export KOMF_METADATA_PROVIDERS_COMIC_VINE_API_KEY=$(cat $CREDENTIALS_DIRECTORY/komf-comicvine-creds);
        #     ''
        #     + lib.optionalString (cfg.providers.bangumi.passwordFile != null) ''
        #       export KOMF_METADATA_PROVIDERS_BANGUMI_TOKEN=$(cat $CREDENTIALS_DIRECTORY/komf-bangumi-creds);
        #     ''
        #   ;

        description = "Komf is a free and open source comics/mangas media server";

        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;

          Type = "simple";
          Restart = "on-failure";
          ExecStart = lib.optionalString (cfg.komga.passwordFile != null) ''
              export KOMF_KOMGA_PASSWORD=$(cat $CREDENTIALS_DIRECTORY/komf-komga-creds);
            ''
            + lib.optionalString (cfg.kavita.passwordFile != null) ''
              export KOMF_KAVITA_API_KEY=$(cat $CREDENTIALS_DIRECTORY/komf-kavita-creds);
            ''
            + lib.optionalString (cfg.providers.mal.passwordFile != null) ''
              export KOMF_METADATA_PROVIDERS_MAL_CLIENT_ID=$(cat $CREDENTIALS_DIRECTORY/komf-mal-creds);
            ''
            + lib.optionalString (cfg.providers.comicvine.passwordFile != null) ''
              export KOMF_METADATA_PROVIDERS_COMIC_VINE_API_KEY=$(cat $CREDENTIALS_DIRECTORY/komf-comicvine-creds);
            ''
            + lib.optionalString (cfg.providers.bangumi.passwordFile != null) ''
              export KOMF_METADATA_PROVIDERS_BANGUMI_TOKEN=$(cat $CREDENTIALS_DIRECTORY/komf-bangumi-creds);
            ''
            + ''
              ${getExe cfg.package} ${applicationYml}
            '';

          LoadCredential = let
            credentialFiles = (lib.optional (cfg.komga.passwordFile != null) "komf-komga-creds:${cfg.komga.passwordFile}")
                              ++ (lib.optional (cfg.kavita.passwordFile != null) "komf-kavita-creds:${cfg.kavita.passwordFile}")
                              ++ (lib.optional (cfg.providers.mal.passwordFile != null) "komf-mal-creds:${cfg.providers.mal.passwordFile}")
                              ++ (lib.optional (cfg.providers.comicvine.passwordFile != null) "komf-comicvine-creds:${cfg.providers.comicvine.passwordFile}")
                              ++ (lib.optional (cfg.providers.bangumi.passwordFile != null) "komf-bangumi-creds:${cfg.providers.bangumi.passwordFile}");
          in
            credentialFiles;

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
