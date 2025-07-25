{
  stdenvNoCC,
  openbao,
  yarn-berry_3,
  nodejs,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = openbao.pname + "-ui";
  inherit (openbao) version src;
  sourceRoot = "${finalAttrs.src.name}/ui";

  offlineCache = yarn-berry_3.fetchYarnBerryDeps {
    inherit (finalAttrs) src sourceRoot;
    hash = "sha256-/SKQC+i8tgpYNVJIem8XDp+v7olGbRRgW25UhhLpIu8=";
  };

  nativeBuildInputs = [
    yarn-berry_3.yarnBerryConfigHook
    nodejs
    yarn-berry_3
  ];

  env.YARN_ENABLE_SCRIPTS = 0;

  postConfigure = ''
    substituteInPlace .ember-cli \
      --replace-fail "../http/web_ui" "$out"
  '';

  buildPhase = "yarn run ember build --environment=production";

  dontInstall = true;
})
