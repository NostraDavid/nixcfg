{
  lib,
  stdenvNoCC,
  stdenv,
  fetchFromGitHub,
  bash,
  coreutils,
  git,
  git-lfs,
  gperftools,
  python311,
  cudaPackages,
  libglvnd,
  glib,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "stable-diffusion-webui";
  version = "1.10.1";

  src = fetchFromGitHub {
    owner = "AUTOMATIC1111";
    repo = "stable-diffusion-webui";
    rev = "v1.10.1";
    hash = "sha256-lY+fZQ9yzFBVX5hrmvaIAm/FaRnsIkB2z4WpcJMmL3w=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -dm755 "$out/share/stable-diffusion-webui"
    cp -R . "$out/share/stable-diffusion-webui"

    install -dm755 "$out/bin"
    cat > "$out/bin/stable-diffusion-webui" <<EOF
#!${bash}/bin/bash
set -euo pipefail

cache_dir="''${XDG_CACHE_HOME:-\$HOME/.cache}/stable-diffusion-webui"
data_dir="''${XDG_DATA_HOME:-\$HOME/.local/share}/stable-diffusion-webui"
${coreutils}/bin/mkdir -p "\$cache_dir" "\$data_dir"

app_dir="\$cache_dir/app"
venv_dir="\$cache_dir/venv"
version="${finalAttrs.src.rev}"

${coreutils}/bin/mkdir -p "\$data_dir"

if [[ ! -f "\$app_dir/.nix-version" ]] || [[ "\$(${coreutils}/bin/cat "\$app_dir/.nix-version")" != "\$version" ]]; then
  ${coreutils}/bin/rm -rf "\$app_dir"
  ${coreutils}/bin/mkdir -p "\$app_dir"
  ${coreutils}/bin/cp -R "$out/share/stable-diffusion-webui/." "\$app_dir/"
  printf "%s" "\$version" > "\$app_dir/.nix-version"
fi

if [[ ! -x "\$venv_dir/bin/python" ]]; then
  ${python311}/bin/python3.11 -m venv "\$venv_dir"
  "\$venv_dir/bin/python" -m pip install --upgrade pip
fi

export GIT="${git}/bin/git"
unset GIT_DIR
unset GIT_WORK_TREE
export PATH="${lib.makeBinPath [coreutils git git-lfs]}:\$PATH"
if [[ -n "''${TORCH_INDEX_URL-}" ]]; then
  export TORCH_INDEX_URL="''${TORCH_INDEX_URL}"
else
  export TORCH_INDEX_URL="https://download.pytorch.org/whl/cu121"
fi
export STABLE_DIFFUSION_REPO="https://github.com/joypaul162/Stability-AI-stablediffusion.git"
export STABLE_DIFFUSION_COMMIT_HASH="f16630a927e00098b524d687640719e4eb469b76"
export CUDA_HOME="${cudaPackages.cudatoolkit}"

taming_dir="\$app_dir/repositories/taming-transformers"
if [[ ! -d "\$taming_dir/.git" ]]; then
  ${coreutils}/bin/mkdir -p "\$app_dir/repositories"
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE "${git}/bin/git" -C "\$app_dir" \
    clone https://github.com/CompVis/taming-transformers.git "\$taming_dir"
fi
export PYTHONPATH="\$taming_dir''${PYTHONPATH:+:\$PYTHONPATH}"

if [[ -n "\$LD_LIBRARY_PATH" ]]; then
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl
    stdenv.cc.cc
    gperftools
    libglvnd
    glib
  ]}:\$LD_LIBRARY_PATH"
else
  export LD_LIBRARY_PATH="${lib.makeLibraryPath [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl
    stdenv.cc.cc
    gperftools
    libglvnd
    glib
  ]}"
fi

if [[ -d /run/opengl-driver/lib ]]; then
  export LD_LIBRARY_PATH="/run/opengl-driver/lib:\$LD_LIBRARY_PATH"
fi
if [[ -d /run/opengl-driver/lib64 ]]; then
  export LD_LIBRARY_PATH="/run/opengl-driver/lib64:\$LD_LIBRARY_PATH"
fi

cd "\$app_dir"
exec "\$venv_dir/bin/python" -u "\$app_dir/launch.py" --data-dir "\$data_dir" "\$@"
EOF
    chmod +x "$out/bin/stable-diffusion-webui"

    runHook postInstall
  '';

  meta = {
    description = "Stable Diffusion web UI by AUTOMATIC1111";
    homepage = "https://github.com/AUTOMATIC1111/stable-diffusion-webui";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "stable-diffusion-webui";
    platforms = lib.platforms.linux;
  };
})
