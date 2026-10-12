{
  description = "juniorsundar.github.io: Hugo site + Typst CV";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }:
    let forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ]
          (s: f nixpkgs.legacyPackages.${s});
    in {
      # CI (.github/workflows/hugo.yml) runs Hugo and Typst from this shell, so flake.lock is the version pin.
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.hugo pkgs.typst ];
          # Fonts modern-cv expects; typst reads TYPST_FONT_PATHS so cv/build.sh needs no flags.
          TYPST_FONT_PATHS = pkgs.lib.makeSearchPath "share/fonts" [ pkgs.roboto pkgs.source-sans pkgs.font-awesome ];
        };
      });
      # The Tailored CV picker (issue #24): `nix run .#pick`. Node is only needed here, not by the site build,
      # so the dev shell CI uses stays at hugo + typst.
      apps = forAll (pkgs: {
        pick = {
          type = "app";
          program = "${pkgs.writeShellScript "cv-pick" ''
            export TYPST_FONT_PATHS=${pkgs.lib.makeSearchPath "share/fonts" [ pkgs.roboto pkgs.source-sans pkgs.font-awesome ]}
            export PATH=${pkgs.nodejs}/bin:${pkgs.typst}/bin:$PATH
            export CV_ROOT="$PWD"
            exec node ${./cv/pick.mjs}
          ''}";
        };
      });
    };
}
