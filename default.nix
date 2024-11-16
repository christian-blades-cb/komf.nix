{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, jdk_headless
}:

stdenvNoCC.mkDerivation rec {
  pname = "komf";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/Snd-R/${pname}/releases/download/${version}/${pname}-${version}.jar";
    hash = "sha256-J5LhN5R3svk4eElQG80MwxHneUapaxXC3FO7QxdW0Ec=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildCommand = ''
    makeWrapper ${jdk_headless}/bin/java $out/bin/komf --add-flags "-jar $src"
  '';

  meta = {
    description = "Komga and Kavita metadata fetcher";
    homepage = "https://github.com/Snd-R/komf";
    license = lib.licenses.mit;
    platforms = jdk_headless.meta.platforms;
    mainProgram = "komf";
  };
}
