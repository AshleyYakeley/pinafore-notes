# https://gvolpe.com/blog/nix-flakes/
# https://nixos.wiki/wiki/Flakes
{
  inputs =
    {
      nixpkgs =
        {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          ref = "nixos-24.11";
        };

      pinafore =
        {
          type = "git";
          url = "https://github.com/AshleyYakeley/Truth";
          submodules = true;
          ref = "master";
        };
    };

  outputs = { self, nixpkgs, pinafore }:
    let
      packages = import nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      app = pinafore.apps.x86_64-linux.pinafore.program;
      src = ./src;
      package = packages.writeScriptBin "pinafore-notes"
        ''
          #!${packages.stdenv.shell}
          ${app} -I ${src} ${src}/pinafore-notes
        '';
    in
    {
      apps.x86_64-linux.default =
        {
          type = "app";
          program = "${package}/bin/pinafore-notes";
        };
      apps.x86_64-linux.pinafore =
        {
          type = "app";
          program = "${app}";
        };
      packages.x86_64-linux.default = package;
      formatter.x86_64-linux = packages.nixpkgs-fmt;
      checks.x86_64-linux.interpret = packages.runCommand "check" { } "${app} -I ${src} -n ${src}/pinafore-notes > $out";
      devShells.x86_64-linux.default = packages.mkShell { buildInputs = with packages; [ just ]; };
    };
}
