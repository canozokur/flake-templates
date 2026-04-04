{
  description = "A project description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
    flake-root.url = "github:srid/flake-root";
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.process-compose-flake.flakeModule
        inputs.flake-root.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          lib,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          devShells = {
            default = pkgs.mkShell {
              inputsFrom = [
                config.flake-root.devShell
              ];

              buildInputs = with pkgs; [
                nixfmt
              ];
            };
          };

          process-compose."changeMe" = {
            imports = [
              inputs.services-flake.processComposeModules.default
            ];

            # services are defined here
            # docs: https://community.flake.parts/services-flake
            # services.nginx."webServer01" = { ... };
          };
        };
    };
}
