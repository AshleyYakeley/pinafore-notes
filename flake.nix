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
      pinafore-notes = packages.runCommand "pinafore-notes" { }
        ''
          sed -e "1s|.*|\#\!${pinafore.packages.x86_64-linux.pinafore}/bin/pinafore|" ${./pinafore-notes} > $out
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
    };
}
