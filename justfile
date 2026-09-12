default: check

nixopts := ""

update:
    nix {{nixopts}} flake update

build:
    nix {{nixopts}} build

format:
    shopt -s globstar && nix {{nixopts}} fmt *.nix

check: format
    nix {{nixopts}} flake check

run:
    nix {{nixopts}} run
