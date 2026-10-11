{
  description = "juniorsundar.github.io: Hugo site + Typst CV";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
          (s: f nixpkgs.legacyPackages.${s});
    in {
      # Keep in sync with HUGO_VERSION in .github/workflows/hugo.yml.
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.hugo pkgs.typst ];
          # Fonts modern-cv expects; typst reads TYPST_FONT_PATHS so cv/build.sh needs no flags.
          TYPST_FONT_PATHS = pkgs.lib.makeSearchPath "share/fonts" [ pkgs.roboto pkgs.source-sans pkgs.font-awesome ];
        };
      });
    };
}
