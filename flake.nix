{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{self, nixpkgs, flake-utils, ...}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        {
          packages.default = pkgs.callPackage ./default.nix {};
        } 
    ) // {
      nixosModules.default = ./module.nix;
      nixosConfigurations.container = nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ({config, ...} : {
            boot.isContainer = true;
            networking.firewall.allowedTCPPorts = [ config.services.komf.port ];

            services.komf = {
              enable = true;
            };

            users.users.admin = {
              isNormalUser = true;
              initialPassword = "admin";
              extraGroups = [ "wheel" ];
            };

            services.openssh = {
              enable = true;
              settings.PasswordAuthentication = true;
            };
          })
        ];
      }; #container
    }; #outputs
}
