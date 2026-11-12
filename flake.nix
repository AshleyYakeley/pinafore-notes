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
          rev = "f6b8825eca9711e71cde19f972c7dab9eb8962b5";
        };
    };

  outputs = { self, nixpkgs, pinafore }:
    let
      packages = import nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };

      joplinPP =
        {
          src = ./joplin;
          package = "pinafore-lib-joplin";
          module = "Pinafore.Library.Joplin";
          name = "joplinPackages";
        };

      pinaforePackage = pinafore.packages.x86_64-linux.pinafore.withPackages (pp: [ pp.pinafore pp.media pp.gnome pp.script joplinPP ]);
      src = ./src;

      package = packages.symlinkJoin {
        name = "pinafore-notes-package";

        paths = [
          (packages.writeShellApplication {
            name = "pinafore-notes";
            runtimeInputs = [ pinaforePackage ];
            text = ''
              pinafore1 -I ${src} ${src}/pinafore-notes "$@"
            '';
          })

          (packages.writeShellApplication {
            name = "import-joplin";
            runtimeInputs = [ pinaforePackage ];
            text = ''
              pinafore1 -I ${src} ${src}/import-joplin "$@"
            '';
          })
        ];
      };
    in
    {
      apps.x86_64-linux.default =
        {
          type = "app";
          program = "${package}/bin/pinafore-notes";
        };
      apps.x86_64-linux.import-joplin =
        {
          type = "app";
          program = "${package}/bin/import-joplin";
        };
      packages.x86_64-linux.default = package;
      formatter.x86_64-linux = packages.nixpkgs-fmt;
      checks.x86_64-linux =
        {
          notes-interpret = packages.runCommand "notes-interpret" { } "${pinaforePackage}/bin/pinafore1 -I ${src} -n ${src}/pinafore-notes > $out";
          import-interpret = packages.runCommand "import-interpret" { } "${pinaforePackage}/bin/pinafore1 -I ${src} -n ${src}/import-joplin > $out";
        };
      devShells.x86_64-linux.default = packages.mkShell { buildInputs = with packages; [ just ]; };
    };
}
