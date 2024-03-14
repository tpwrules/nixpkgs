{ rustPlatform
, stdenv
, lib
, darwin
, fetchFromGitLab
, openssl

# for skia-bindings, based on the neovide package
, python3
, fetchgit
, fetchFromGitHub
, linkFarm
, runCommand
, gn
, ninja
, xcbuild
}:

rustPlatform.buildRustPackage rec {
  pname = "surfer";
  version = "unstable-2024-02-11";

  src = fetchFromGitLab {
    owner = "surfer-project";
    repo = "surfer";
    rev = "fb34a4f4e958a329c1454b960e22cd9ba1f9ebf9";
    hash = "sha256-uj817uFSp88ZtKc/WYAbNzyp3BnOYLNpfLet80Y4uFk=";
    fetchSubmodules = true;
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "codespan-0.12.0" = "sha256-3F2006BR3hyhxcUTaQiOjzTEuRECKJKjIDyXonS/lrE=";
      "egui_skia-0.5.0" = "sha256-dpkcIMPW+v742Ov18vjycLDwnn1JMsvbX6qdnuKOBC4=";
      "tracing-tree-0.2.0" = "sha256-/JNeAKjAXmKPh0et8958yS7joORDbid9dhFB0VUAhZc=";
    };
  };

  SKIA_SOURCE_DIR =
    let
      repo = fetchFromGitHub {
        owner = "rust-skia";
        repo = "skia";
        # see rust-skia:skia-bindings/Cargo.toml#package.metadata skia,
        # or the appropriate error message when SKIA_SOURCE_DIR is missing
        rev = "m120-0.68.1";
        sha256 = "sha256-UtCHqKKuXGP699nm4kZN46Nhw+u3Wj1rQ9VUHiyUTlI=";
      };
      # The externals for skia are taken from skia/DEPS
      externals = linkFarm "skia-externals" (lib.mapAttrsToList
        (name: value: { inherit name; path = fetchgit value; })
        (lib.importJSON ./skia-externals.json));
    in
    runCommand "source" { } ''
      cp -R ${repo} $out
      chmod -R +w $out
      ln -s ${externals} $out/third_party/externals
    ''
  ;

  SKIA_GN_COMMAND = "${gn}/bin/gn";
  SKIA_NINJA_COMMAND = "${ninja}/bin/ninja";

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    python3
  ] ++ lib.optionals stdenv.isDarwin [ xcbuild ];

  buildInputs = [
    openssl
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
    darwin.apple_sdk.frameworks.AppKit
    darwin.apple_sdk.frameworks.CoreFoundation
    darwin.apple_sdk.frameworks.OpenGL
    darwin.apple_sdk.frameworks.CoreServices
    darwin.apple_sdk.frameworks.Foundation
    darwin.apple_sdk.frameworks.QuartzCore
    darwin.apple_sdk.frameworks.ApplicationServices
    darwin.apple_sdk.frameworks.CoreGraphics
    darwin.apple_sdk.frameworks.CoreVideo
    darwin.apple_sdk.frameworks.Carbon
    darwin.apple_sdk.frameworks.CoreData
    darwin.apple_sdk.frameworks.Accelerate
  ];

  env = lib.optionalAttrs stdenv.isDarwin {
    # Work around https://github.com/NixOS/nixpkgs/issues/166205
    NIX_LDFLAGS = "-l${stdenv.cc.libcxx.cxxabi.libName}";
  };

  # tests fail on macOS due to platform specific rendering differences
  checkFlags = lib.optional stdenv.isDarwin [
    "--skip=tests::snapshot::dialogs_work"
    "--skip=tests::snapshot::hierarchy_separate"
    "--skip=tests::snapshot::hierarchy_tree"
    "--skip=tests::snapshot::menu_can_be_hidden"
    "--skip=tests::snapshot::quick_start_works"
    "--skip=tests::snapshot::side_panel_can_be_hidden"
    "--skip=tests::snapshot::startup_screen_looks_fine"
    "--skip=tests::snapshot::toolbar_can_be_hidden"
  ];

  # not true with the current version of skia but just in case
  disallowedReferences = [ SKIA_SOURCE_DIR ];
}
