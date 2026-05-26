{
  inputs = {
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  nixConfig = {
    extra-substituters = "https://nixpkgs-terraform.cachix.org";
    extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
  };

  outputs = { self, nixpkgs-terraform, nixpkgs, systems }:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            # CHANGE THIS see the versions: https://github.com/stackbuilders/nixpkgs-terraform/blob/main/versions.json
            version = "1.5.7";
            terraform = nixpkgs-terraform.packages.${system}.${version};
          in
          {
            default = pkgs.mkShell {
              buildInputs = [ terraform ];
              shellHook = ''
                alias tf=terraform
              '';
            };
          });
    };
}
