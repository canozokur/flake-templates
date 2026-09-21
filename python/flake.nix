{
  description = "A project description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
        let
          # adjust build-system/dependencies to match pyproject.toml's build backend
          # and this project's own dependencies (this defaults to hatchling)
          pythonApplicationPackage = pkgs.python3Packages.buildPythonApplication {
            pname = "pythonApplication";
            version = "local";
            pyproject = true;
            src = ./.;

            build-system = with pkgs.python3Packages; [
              hatchling
            ];

            dependencies = with pkgs.python3Packages; [ ];
          };
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # we can export the package here
          packages.default = pythonApplicationPackage;

          devShells = {
            default = pkgs.mkShell {
              inputsFrom = [
                config.flake-root.devShell
              ];

              nativeBuildInputs = with pkgs; [
                python3
                git
                just
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

            settings.processes."pythonApplication" = {
              command = "${lib.getExe pythonApplicationPackage}";
            };
          };
        };
    };
}
