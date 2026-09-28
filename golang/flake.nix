{
  description = "A project description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
    flake-root.url = "github:srid/flake-root";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.process-compose-flake.flakeModule
        inputs.flake-root.flakeModule
        inputs.git-hooks-nix.flakeModule
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
          goApplicationPackage = pkgs.buildGoApplication {
            pname = "goApplication";
            version = "local";
            pwd = ./.;
            src = ./.;
            modules = ./gomod2nix.toml;

            CGO_ENABLED = 0;

            # modules are fetched per-module with GOPROXY as an impure env var, so a custom
            # proxy has to be set in the nix-daemon's environment rather than here.

            # must match the binary name, which go derives from the module path in go.mod
            meta.mainProgram = "goApplication";

            # disable running `go test` on each build
            doCheck = false;
          };
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.gomod2nix.overlays.default ];
          };

          # we can export the package here
          packages.default = goApplicationPackage;

          # the hook needs network access for new modules, which the sandboxed check lacks
          pre-commit.check.enable = false;
          pre-commit.settings.hooks.gomod2nix = {
            enable = true;
            name = "gomod2nix";
            entry = lib.getExe' pkgs.gomod2nix "gomod2nix";
            files = "(^|/)go\\.(mod|sum)$";
            pass_filenames = false;
          };

          devShells = {
            default = pkgs.mkShell {
              inputsFrom = [
                config.flake-root.devShell
                config.pre-commit.devShell
              ];

              nativeBuildInputs = with pkgs; [
                go
                git
                just
                gomod2nix
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
