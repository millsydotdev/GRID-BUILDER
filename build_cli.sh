#!/usr/bin/env bash

set -ex

cd cli

export CARGO_NET_GIT_FETCH_WITH_CLI="true"
export VSCODE_CLI_APP_NAME="$( echo "${APP_NAME}" | awk '{print tolower($0)}' )"
export VSCODE_CLI_BINARY_NAME="$( node -p "require(\"../product.json\").serverApplicationName" )"
export VSCODE_CLI_UPDATE_ENDPOINT="https://grideditor.com/api/update" # GRID

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  export VSCODE_CLI_DOWNLOAD_ENDPOINT="https://grideditor.com/insiders/download"
else
  export VSCODE_CLI_DOWNLOAD_ENDPOINT="https://grideditor.com/download" # GRID
fi

TUNNEL_APPLICATION_NAME="$( node -p "require(\"../product.json\").tunnelApplicationName" )"
NAME_SHORT="$( node -p "require(\"../product.json\").nameShort" )"

npm pack @vscode/openssl-prebuilt@0.0.11
mkdir openssl
tar -xvzf vscode-openssl-prebuilt-0.0.11.tgz --strip-components=1 --directory=openssl

if [[ "${OS_NAME}" == "osx" ]]; then
  if [[ "${VSCODE_ARCH}" == "arm64" ]]; then
    VSCODE_CLI_TARGET="aarch64-apple-darwin"
  else
    VSCODE_CLI_TARGET="x86_64-apple-darwin"
  fi

  export OPENSSL_LIB_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-osx/lib"
  export OPENSSL_INCLUDE_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-osx/include"

  cargo build --release --target "${VSCODE_CLI_TARGET}" --bin=code

  # Copy to app bundle - keep as tunnel name for internal consistency if needed by app
  cp "target/${VSCODE_CLI_TARGET}/release/code" "../../VSCode-darwin-${VSCODE_ARCH}/${NAME_SHORT}.app/Contents/Resources/app/bin/${TUNNEL_APPLICATION_NAME}"

  # Create standalone CLI artifact for npm
  CLI_ASSET_NAME="${APP_NAME_LC}-cli-darwin-${VSCODE_ARCH}.zip"
  echo "Creating standalone CLI artifact: ${CLI_ASSET_NAME}"

  mkdir -p "target/${VSCODE_CLI_TARGET}/release/cli_pack"
  # Package as 'grid' so users have the expected command
  cp "target/${VSCODE_CLI_TARGET}/release/code" "target/${VSCODE_CLI_TARGET}/release/cli_pack/grid"

  pushd "target/${VSCODE_CLI_TARGET}/release/cli_pack"
  zip -r "../../../../../../../assets/${CLI_ASSET_NAME}" "grid"
  popd
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${VSCODE_ARCH}" == "arm64" ]]; then
    VSCODE_CLI_TARGET="aarch64-pc-windows-msvc"
    export VSCODE_CLI_RUST="-C target-feature=+crt-static -Clink-args=/guard:cf -Clink-args=/CETCOMPAT:NO"
  else
    VSCODE_CLI_TARGET="x86_64-pc-windows-msvc"
    export VSCODE_CLI_RUSTFLAGS="-Ctarget-feature=+crt-static -Clink-args=/guard:cf -Clink-args=/CETCOMPAT"
  fi

  export VSCODE_CLI_CFLAGS="/guard:cf /Qspectre"
  export OPENSSL_LIB_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-windows-static/lib"
  export OPENSSL_INCLUDE_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-windows-static/include"

  rustup target add "${VSCODE_CLI_TARGET}"

  cargo build --release --target "${VSCODE_CLI_TARGET}" --bin=code

  cp "target/${VSCODE_CLI_TARGET}/release/code.exe" "../../VSCode-win32-${VSCODE_ARCH}/bin/${TUNNEL_APPLICATION_NAME}.exe"

  # Create standalone CLI artifact for npm
  CLI_ASSET_NAME="${APP_NAME_LC}-cli-win32-${VSCODE_ARCH}.zip"
  echo "Creating standalone CLI artifact: ${CLI_ASSET_NAME}"

  mkdir -p "target/${VSCODE_CLI_TARGET}/release/cli_pack"
  # Package as 'grid.exe'
  cp "target/${VSCODE_CLI_TARGET}/release/code.exe" "target/${VSCODE_CLI_TARGET}/release/cli_pack/grid.exe"

  # Use 7z if available
  pushd "target/${VSCODE_CLI_TARGET}/release/cli_pack"
  7z.exe a -tzip "../../../../../../../assets/${CLI_ASSET_NAME}" "grid.exe"
  popd
else
  export OPENSSL_LIB_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-linux/lib"
  export OPENSSL_INCLUDE_DIR="$( pwd )/openssl/out/${VSCODE_ARCH}-linux/include"
  export VSCODE_SYSROOT_DIR="../.build/sysroots"

  if [[ "${VSCODE_ARCH}" == "arm64" ]]; then
    VSCODE_CLI_TARGET="aarch64-unknown-linux-gnu"

    if [[ "${CI_BUILD}" != "no" ]]; then
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
      export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
      export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
      export PKG_CONFIG_ALLOW_CROSS=1
    fi
  elif [[ "${VSCODE_ARCH}" == "armhf" ]]; then
    VSCODE_CLI_TARGET="armv7-unknown-linux-gnueabihf"

    export OPENSSL_LIB_DIR="$( pwd )/openssl/out/arm-linux/lib"
    export OPENSSL_INCLUDE_DIR="$( pwd )/openssl/out/arm-linux/include"

    if [[ "${CI_BUILD}" != "no" ]]; then
      export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
      export CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc
      export CXX_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-g++
      export PKG_CONFIG_ALLOW_CROSS=1
    fi
  elif [[ "${VSCODE_ARCH}" == "x64" ]]; then
    VSCODE_CLI_TARGET="x86_64-unknown-linux-gnu"
  fi

  if [[ -n "${VSCODE_CLI_TARGET}" ]]; then
    rustup target add "${VSCODE_CLI_TARGET}"

    cargo build --release --target "${VSCODE_CLI_TARGET}" --bin=code

    # Copy to the main app bundle
    cp "target/${VSCODE_CLI_TARGET}/release/code" "../../VSCode-linux-${VSCODE_ARCH}/bin/${TUNNEL_APPLICATION_NAME}"

    # Create standalone CLI artifact for npm
    CLI_ASSET_NAME="${APP_NAME_LC}-cli-linux-${VSCODE_ARCH}.tar.gz"
    echo "Creating standalone CLI artifact: ${CLI_ASSET_NAME}"

    # Create a temporary directory for packing
    mkdir -p "target/${VSCODE_CLI_TARGET}/release/cli_pack"
    # Package as 'grid'
    cp "target/${VSCODE_CLI_TARGET}/release/code" "target/${VSCODE_CLI_TARGET}/release/cli_pack/grid"

    # Tar it up
    tar -czf "../../assets/${CLI_ASSET_NAME}" -C "target/${VSCODE_CLI_TARGET}/release/cli_pack" "grid"
  fi
fi

cd ..
