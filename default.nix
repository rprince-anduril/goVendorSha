# goVendorSha/calculate.nix
# calculate the vendorSha256 value for go.mod/go.sum changes
# based on the proxyVendor code in pkgs/build-support/go/module.nix
{
  nixpkgs ? import <nixpkgs> {}
, srcRoot
, goVersion ? "1.18"
}:
let
  inherit (nixpkgs) git cacert go_1_17 go_1_18 go_1_19;
  go = {
    "1.17" = go_1_17;
    "1.18" = go_1_18;
    "1.19" = go_1_19;
  }.${goVersion};
  inherit (go) GOOS GOARCH;
  src = builtins.fetchGit "git+file:${srcRoot}";
in
nixpkgs.stdenv.mkDerivation {
  inherit src;

  name = "temp-go-modules";
  outputHashAlgo = "sha256";
  outputHash = nixpkgs.lib.fakeHash;

  nativeBuildInputs = [ go git cacert ];
  GO111MODULE = "on";

  configurePhase = ''
    runHook preConfigure
    export GOCACHE=$TMPDIR/go-cache
    export GOPATH="$TMPDIR/go"
    cd "${src}"
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    if [ -d vendor ]; then
      echo "vendor folder exists, please set 'vendorHash = null;' or 'vendorSha256 = null;' in your expression"
      exit 10
    fi
    mkdir -p "''${GOPATH}/pkg/mod/cache/download"
    go mod download
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    rm -rf "''${GOPATH}/pkg/mod/cache/download/sumdb"
    cp -r --reflink=auto "''${GOPATH}/pkg/mod/cache/download" $out
    runHook postInstall
  '';

  dontFixup = true;
  outputHashMode = "recursive";
}
