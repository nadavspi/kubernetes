{
  inputs = {nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";};

  outputs = {
    self,
    nixpkgs,
  }: let
    overlays = [];
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {
            inherit overlays system;
            config.allowUnfree = true;
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          age
          fluxcd
          k9s
          kubectl
          kubernetes-helm
          kustomize
          sops
        ];
      };
    });
  };
}
