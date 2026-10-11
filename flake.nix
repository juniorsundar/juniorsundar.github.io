{
  description = "juniorsundar.github.io: Hugo dev shell";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
          (s: f nixpkgs.legacyPackages.${s});
    in {
      # Keep in sync with HUGO_VERSION in .github/workflows/hugo.yml.
      devShells = forAll (pkgs: { default = pkgs.mkShell { packages = [ pkgs.hugo ]; }; });
    };
}
