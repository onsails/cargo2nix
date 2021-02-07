{
  inputs = {
    utils.url = github:numtide/flake-utils;
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, utils, rust-overlay, ... }@inputs:
    let cargo2nixOverlay = import ./overlay;
    in
    {
      overlay = cargo2nixOverlay;
    } // utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            cargo2nixOverlay
            rust-overlay.overlay
          ];
        };
        rustChannel = "stable";
        rustPkgs =
          pkgs.rustBuilder.makePackageSet' {
            packageFun = import ./Cargo.nix;
            inherit rustChannel;
            packageOverrides = pkgs: pkgs.rustBuilder.overrides.all;
            localPatterns = [ ''^(src|tests|templates)(/.*)?'' ''[^/]*\.(rs|toml)$'' ];
          };
      in
      {
        packages = {
          cargo2nix = rustPkgs.workspace.cargo2nix { };
          ci = pkgs.rustBuilder.runTests rustPkgs.workspace.cargo2nix { };
        };

        defaultPackage = self.packages.${system}.cargo2nix;
        defaultApp = {
          type = "app";
          program = "${self.defaultPackage.${system}}/bin/cargo2nix";
        };
      });
}
