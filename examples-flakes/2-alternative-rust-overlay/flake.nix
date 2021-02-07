{
  inputs = {
    rust-overlay.url = "github:oxalica/rust-overlay";
    cargo2nix.url = github:onsails/cargo2nix/flake;
    utils.url = github:numtide/flake-utils;
  };

  outputs = { nixpkgs, utils, cargo2nix, rust-overlay, ... }: utils.lib.eachDefaultSystem (system:
    let
      rustChannel = "1.49.0";
      rustChannelSha256 = "KCh2UBGtdlBJ/4UOqZlxUtcyefv7MH1neoVNV4z0nWs=";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlay
          cargo2nix.overlay
          (
            self: super: {
              rustStable = (
                super.rustChannelOf {
                  channel = rustChannel;
                }
              ).rust;
            }
          )
        ];
      };
      rustPkgs = pkgs.rustBuilder.makePackageSet' {
        inherit rustChannel;
        packageFun = import ./Cargo.nix;
      };
    in
    {
      defaultPackage = rustPkgs.workspace.hello-world { };

      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustStable
        ];
      };
    }
  );
}
