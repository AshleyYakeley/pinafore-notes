default: check

update:
    nix flake update

build:
    nix build

format:
    nix fmt

check: format
    nix flake check
