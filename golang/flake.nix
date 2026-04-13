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
        let
          goApplicationPackage = pkgs.buildGoModule rec {
            pname = "goApplication";
            version = "local";
            src = ./.;

            env = {
              CGO_ENABLED = 0;
            };

            # unfortunately setting GOPROXY in `env` does not propagate to the module
            # derivation builder, we need to override the module attrs and add a preBuild phase
            # and set GOPROXY there. Not the best, not the worst either.
            overrideModAttrs = (
              prev: {
                preBuild = ''
                  echo "running preBuild"
                  GOPROXY="https://example.com"
                '';
              }
            );

            # disable running `go test` on each build
            doCheck = false;

            # this needs to be updated when go.mod changes
            vendorHash = lib.fakeHash;
          };
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          # we can export the package here
          packages.default = goApplicationPackage;

          devShells = {
            default = pkgs.mkShell {
              inputsFrom = [
                config.flake-root.devShell
              ];

              nativeBuildInputs = with pkgs; [
                go
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

            settings.processes."goApplication" = {
              command = "${lib.getExe goApplicationPackage}";
            };
          };
        };
    };
}
