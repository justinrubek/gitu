{
  inputs,
  self,
  ...
} @ part-inputs: {
  imports = [];

  perSystem = {
    config,
    pkgs,
    lib,
    system,
    inputs',
    self',
    ...
  }: let
    extraPackages =
      [
        pkgs.pkg-config
        pkgs.libgit2
        pkgs.openssl
        pkgs.openssl.dev
        pkgs.zlib
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        pkgs.libiconv
        pkgs.darwin.apple_sdk.frameworks.AppKit
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
        pkgs.darwin.apple_sdk.frameworks.CoreServices
        pkgs.darwin.apple_sdk.frameworks.Foundation
        pkgs.darwin.apple_sdk.frameworks.Security
      ];
    withExtraPackages = base: base ++ extraPackages;

    craneLib = inputs.crane.lib.${system}.overrideToolchain self'.packages.rust-toolchain;

    commonArgs = rec {
      src = inputs.nix-filter.lib {
        root = ../.;
        include = [
          "Cargo.toml"
          "Cargo.lock"
          "benches"
          "src"
          "tests"
        ];
      };

      pname = "gitu";

      nativeBuildInputs = withExtraPackages [];
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeBuildInputs;
      SQLX_OFFLINE = true;
    };

    cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    packages = {
      default = packages.gitu;
      gitu = craneLib.buildPackage ({
          pname = "gitu";
          inherit cargoArtifacts;
          cargoExtraArgs = "--bin gitu";
          meta.mainProgram = "gitu";
        }
        // commonArgs);

      cargo-doc = craneLib.cargoDoc ({
          inherit cargoArtifacts;
        }
        // commonArgs);
    };

    checks = {
      clippy = craneLib.cargoClippy (commonArgs
        // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-features -- --deny warnings";
        });

      rust-fmt = craneLib.cargoFmt (commonArgs
        // {
          inherit (commonArgs) src;
        });

      rust-tests = craneLib.cargoNextest (commonArgs
        // {
          inherit cargoArtifacts;
          partitions = 1;
          partitionType = "count";
        });
    };
  in rec {
    inherit packages checks;

    apps = {
      gitu = {
        type = "app";
        program = pkgs.lib.getBin self'.packages.gitu;
      };
      default = apps.gitu;
    };

    legacyPackages = {
      cargoExtraPackages = extraPackages;
    };
  };
}
