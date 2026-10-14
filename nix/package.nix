{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}:

let
  root = ../.;
in
stdenvNoCC.mkDerivation {
  pname = "watermarks-remover";
  inherit ((lib.importJSON (root + "/.claude-plugin/plugin.json"))) version;

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions [
      (root + "/service")
      (root + "/skills")
      (root + "/config")
      (root + "/hooks")
      (root + "/.claude-plugin")
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  # The Makefile's default target runs pytest. Tests run as a flake check.
  dontConfigure = true;
  dontBuild = true;

  # Skills reference sibling paths such as service/scripts/*, so the tree is
  # vendored whole and only real entry points get a wm-<name> wrapper.
  installPhase = ''
    runHook preInstall

    share="$out/share/watermarks-remover"
    mkdir -p "$share" "$out/bin"
    cp -r service skills config hooks .claude-plugin "$share/"

    for f in "$share"/service/scripts/*.py; do
      grep -q '__name__ == "__main__"' "$f" || continue
      makeWrapper ${python3}/bin/python3 "$out/bin/wm-$(basename "$f" .py)" \
        --add-flags "$f" \
        --set PYTHONPATH "$share"
    done

    runHook postInstall
  '';

  meta = {
    description = "Strip AI provenance marks (C2PA, invisible Unicode) and file metadata";
    homepage = "https://github.com/Qubasa/watermarks-remover";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
