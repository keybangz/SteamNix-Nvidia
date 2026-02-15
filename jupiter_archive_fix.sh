while nix-build --no-out-link --arg nixpkgs 'import <nixpkgs> {}' --attr pkgs.jupiter-hw-support.src.src; do
  nix-store --delete $( nix-instantiate --eval --expr '"${(import ./. {}).pkgs.jupiter-hw-support.src.src}"' | tr -d '"' )
done
