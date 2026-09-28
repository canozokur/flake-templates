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
    let
      # private module settings for this project
      goProxy = "https://goproxy.example.com/";
      goNoSumDb = "github.com/example-org/*";
    in
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
          # the module fetcher only passes GOPROXY through from the nix-daemon and never GONOSUMDB,
          # so private modules can't be fetched without injecting both into gomod2nix's fetcher.
          # `pkgs` can't be used here as it's the result of this overlay.
          gomod2nixSrc = nixpkgs.legacyPackages.${system}.applyPatches {
            name = "gomod2nix-private-src";
            src = inputs.gomod2nix;
            postPatch = ''
              substituteInPlace builder/fetch.sh --replace-fail \
                'export HOME=$(mktemp -d)' \
                'export HOME=$(mktemp -d)
              export GOPROXY="${goProxy}"
              export GONOSUMDB="${goNoSumDb}"'
            '';
          };

          goApplicationPackage = pkgs.buildGoApplication {
            pname = "goApplication";
            version = "local";
            pwd = ./.;
            src = ./.;
            modules = ./gomod2nix.toml;

            CGO_ENABLED = 0;

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
            overlays = [ (import "${gomod2nixSrc}/overlay.nix") ];
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

              env = {
                GOPROXY = goProxy;
                GONOSUMDB = goNoSumDb;
              };
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
