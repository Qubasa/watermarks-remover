{
  description = "Strip AI provenance marks (C2PA, invisible Unicode) and file metadata";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem =
        f: lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f nixpkgs.legacyPackages.${system});

      devPython = pkgs: pkgs.python3.withPackages (ps: [ ps.pytest ]);

      repoFormatter =
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
          programs.ruff-format.enable = true;
        };
    in
    {
      treefmtModules.default = ./nix/treefmt-module.nix;

      packages = eachSystem (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.watermarks-remover;
        watermarks-remover = pkgs.callPackage ./nix/package.nix { };
      });

      formatter = eachSystem (pkgs: (repoFormatter pkgs).config.build.wrapper);

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (devPython pkgs)
            pkgs.ruff
          ];
        };
      });

      checks = eachSystem (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          package = self.packages.${system}.default;

          formatting = (repoFormatter pkgs).config.build.check self;

          pytest =
            pkgs.runCommand "watermarks-remover-pytest" { nativeBuildInputs = [ (devPython pkgs) ]; }
              ''
                cp -r ${self} src && chmod -R u+w src && cd src
                export HOME="$TMPDIR"
                python -m pytest -p no:cacheprovider
                touch "$out"
              '';

          ruff = pkgs.runCommand "watermarks-remover-ruff" { nativeBuildInputs = [ pkgs.ruff ]; } ''
            cd ${self}
            ruff check --no-cache service tests
            touch "$out"
          '';

          treefmt-module = pkgs.callPackage ./nix/treefmt-module-test.nix {
            treefmt = treefmt-nix.lib.evalModule pkgs {
              imports = [ self.treefmtModules.default ];
              projectRootFile = "treefmt-root";
              programs.watermarks-remover.enable = true;
            };
          };
        }
      );
    };
}
