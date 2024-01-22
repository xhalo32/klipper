{
  description = "Klipper";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        packages.default = with pkgs; stdenv.mkDerivation rec {
          pname = "klipper";
          version = "xhalo32-2024-01-22";

          src = ./.;

          # NB: This is needed for the postBuild step
          nativeBuildInputs = [
            (python3.withPackages ( p: with p; [ cffi ] ))
            makeWrapper
          ];

          buildInputs = [ (python3.withPackages (p: with p; [ can cffi pyserial greenlet jinja2 markupsafe numpy ])) ];

          # we need to run this to prebuild the chelper.
          postBuild = ''
    python ./chelper/__init__.py
  '';

          # Python 3 is already supported but shebangs aren't updated yet
          postPatch = ''
    cd klippy
    for file in klippy.py console.py parsedump.py; do
      substituteInPlace $file \
        --replace '/usr/bin/env python2' '/usr/bin/env python'
    done

    # needed for cross compilation
    substituteInPlace ./chelper/__init__.py \
      --replace 'GCC_CMD = "gcc"' 'GCC_CMD = "${stdenv.cc.targetPrefix}cc"'
  '';

          # NB: We don't move the main entry point into `/bin`, or even symlink it,
          # because it uses relative paths to find necessary modules. We could wrap but
          # this is used 99% of the time as a service, so it's not worth the effort.
          installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/klipper
    cp -r ./* $out/lib/klipper

    # Moonraker expects `config_examples` and `docs` to be available
    # under `klipper_path`
    cp -r $src/docs $out/lib/docs
    cp -r $src/config $out/lib/config

    mkdir -p $out/bin
    chmod 755 $out/lib/klipper/klippy.py
    makeWrapper $out/lib/klipper/klippy.py $out/bin/klippy --chdir $out/lib/klipper
    runHook postInstall
  '';
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
}
