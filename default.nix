{ pkgs ? (import ./nix/nixpkgs { inherit system; })
, system ? builtins.currentSystem
, ormoluCompiler ? "ghc8102"
}:

let
  source = pkgs.lib.sourceByRegex ./. [
    "^.*\.md$"
    "^app.*$"
    "^data.*$"
    "^ormolu\.cabal$"
    "^src.*$"
    "^tests.*$"
    ];
  haskellPackages = pkgs.haskell.packages.${ormoluCompiler}.override {
    overrides = ormoluOverlay;
  };
  ormoluOverlay = self: super: {
    "ormolu" = super.callCabal2nixWithOptions "ormolu" source "-fdev" { };
  };
  ormolize = import ./nix/ormolize {
    inherit pkgs;
    inherit haskellPackages;
  };
  expectedFailures = [
    "Agda"
    "aws"
    "distributed-process"
    "esqueleto"
    "fay"
    "hlint"
    "idris"
    "intero"
    "leksah"
    "pandoc"
    "pipes"
    "postgrest"
    "purescript"
    "tensorflow"
  ] ++ (if ormoluCompiler == "ghc8102" then [] else ["lens"]);
  ormolizedPackages = doCheck:
    pkgs.lib.mapAttrs (name: p: ormolize {
      package = p;
      inherit doCheck;
      expectedFailures =
        if pkgs.lib.lists.any (x: x == name) expectedFailures
          then ./expected-failures + "/${name}.txt"
          else null;
    }) haskellPackages;
in {
  ormolu = haskellPackages.ormolu;
  # We put the derivations in another attribute set to avoid building them
  # when nix-build is run.
  dev = {
    ormoluShell =
      haskellPackages.shellFor {
        packages = ps: [
          ps.ormolu
        ];
        buildInputs = [
          haskellPackages.cabal-install
          haskellPackages.ghcid
        ];
      };
    withOrmolu = haskellPackages.shellFor {
      packages = ps: [];
      buildInputs = [
        haskellPackages.cabal-install
        haskellPackages.ormolu
      ];
    };
  };
  inherit ormoluOverlay ormoluCompiler;
  hackage = ormolizedPackages false;
  hackageTests = with pkgs.lib; pkgs.recurseIntoAttrs (
    let ps = [
      "Agda"
      "QuickCheck"
      "ShellCheck"
      "aeson"
      "attoparsec"
      "aws"
      "brick"
      "capability"
      "cassava"
      "conduit"
      "cryptonite"
      "diagrams-core"
      "distributed-process"
      "esqueleto"
      "fay"
      "hakyll"
      "haxl"
      "hedgehog"
      "hledger"
      "hlint"
      "http-client"
      "idris"
      "intero"
      "leksah"
      "lens"
      "megaparsec"
      "optics"
      "ormolu"
      "pandoc"
      "parsec3"
      "pipes"
      "postgrest"
      "purescript"
      "servant"
      "servant-server"
      "stack"
      "tensorflow"
      "text_1_2_4_0"
      "tls"
      "yesod-core"
    ];
    in listToAttrs (map (p: nameValuePair p (ormolizedPackages true).${p}) ps)
  );
  regionTests = pkgs.stdenv.mkDerivation {
    name = "ormolu-region-tests";
    src = ./region-tests;
    buildInputs = [
      haskellPackages.ormolu
      pkgs.diffutils
    ];
    doCheck = true;
    buildPhase = ''
      cp src.hs result-all-implicit.hs
      ormolu --check-idempotence --mode inplace result-all-implicit.hs
      cp src.hs result-all-explicit.hs
      ormolu --check-idempotence --mode inplace --start-line 1 --end-line 18 result-all-explicit.hs
      cp src.hs result-only-start.hs
      ormolu --check-idempotence --mode inplace --start-line 1 result-only-start.hs
      cp src.hs result-only-end.hs
      ormolu --check-idempotence --mode inplace --end-line 18 result-only-end.hs
      cp src.hs result-6-7.hs
      ormolu --check-idempotence --mode inplace --start-line 6 --end-line 7 result-6-7.hs
      cp src.hs result-6-8.hs
      ormolu --check-idempotence --mode inplace --start-line 6 --end-line 8 result-6-8.hs
      cp src.hs result-9-12.hs
      ormolu --check-idempotence --mode inplace --start-line 9 --end-line 12 result-9-12.hs
      cp src.hs result-17-18.hs
      ormolu --check-idempotence --mode inplace --start-line 17 --end-line 18 result-17-18.hs
    '';
    checkPhase = ''
      echo result-all-implicit.hs
      diff --color=always expected-result-all.hs result-all-implicit.hs
      echo result-all-explicit.hs
      diff --color=always expected-result-all.hs result-all-explicit.hs
      echo result-only-start.hs
      diff --color=always expected-result-all.hs result-only-start.hs
      echo result-only-end.hs
      diff --color=always expected-result-all.hs result-only-end.hs
      echo result-6-7.hs
      diff --color=always expected-result-6-7.hs result-6-7.hs
      echo result-6-8.hs
      diff --color=always expected-result-6-8.hs result-6-8.hs
      echo result-9-12.hs
      diff --color=always expected-result-9-12.hs result-9-12.hs
      echo result-17-18.hs
      diff --color=always expected-result-17-18.hs result-17-18.hs
    '';
    installPhase = ''
      mkdir "$out"
      find . -name '*.hs' -exec cp --parents {} $out \;
    '';
  };
}
