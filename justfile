default: check

nixopts := ""

update:
    nix {{nixopts}} flake update

build:
    nix {{nixopts}} build

format:
    nix {{nixopts}} fmt

check: format
    nix {{nixopts}} flake check

run:
    nix {{nixopts}} run
