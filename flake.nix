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
          ref = "nixos-24.05";
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
      pinafore-notes = packages.runCommandLocal "pinafore-notes" { }
        ''
          sed -e "1s|.*|\#\!${app}|" ${./pinafore-notes} > $out
          chmod 755 $out
        '';
    in
    {
      apps.x86_64-linux.default =
        {
          type = "app";
          program = "${pinafore-notes}";
        };
      packages.x86_64-linux.default = packages.runCommand "pinafore-notes" { }
        ''
          mkdir -p $out/bin
          ln -s ${pinafore-notes} $out/bin/pinafore-notes
        '';
      formatter.x86_64-linux = packages.nixpkgs-fmt;
      checks.x86_64-linux.interpret = packages.runCommand "check" { } "${app} -n ${pinafore-notes} > $out";
      testapp = app;
    };
}
