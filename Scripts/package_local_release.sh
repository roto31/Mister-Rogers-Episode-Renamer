#!/usr/bin/env bash
# Produce MisterRogersRenamer.app + zip under build/Releases/<semver>/macos-<arch>/.
# SemVer / bundled catalog: run after updating MARKETING_VERSION (and CHANGELOG) per RELEASING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

PBX="${ROOT}/MacApp/MisterRogersRenamer.xcodeproj/project.pbxproj"

read_marketing_version() {
  # First MARKETING_VERSION assignment in pbxproj
  grep -m1 'MARKETING_VERSION = ' "${PBX}" | sed -E 's/^[[:space:]]*MARKETING_VERSION = ([^;]+);/\1/' | tr -d '[:space:]'
}

read_current_project_version() {
  grep -m1 'CURRENT_PROJECT_VERSION = ' "${PBX}" | sed -E 's/^[[:space:]]*CURRENT_PROJECT_VERSION = ([^;]+);/\1/' | tr -d '[:space:]'
}

VERSION="${1:-}"
BUILD_NUM="${2:-}"

if [[ -z "${VERSION}" ]]; then
  VERSION="$(read_marketing_version)"
fi

if [[ -z "${VERSION}" ]]; then
  echo "ERROR: could not read MARKETING_VERSION from project; pass semver as arg 1." >&2
  exit 2
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  echo "ERROR: invalid SemVer for release folder: ${VERSION}" >&2
  exit 2
fi

if [[ -z "${BUILD_NUM}" ]]; then
  BUILD_NUM="$(read_current_project_version)"
fi

ARCH="$(uname -m)"
OUT_DIR="${ROOT}/build/Releases/${VERSION}/macos-${ARCH}"
DERIVED="${ROOT}/build/DerivedData"
APP_SRC="${DERIVED}/Build/Products/Release/MisterRogersRenamer.app"
ZIP_NAME="MisterRogersRenamer-macos-${ARCH}.zip"

echo "==> Verify bundled catalog"
python3 Scripts/verify_bundled_catalog.py

echo "==> Swift test"
swift test

echo "==> xcodebuild Release (MARKETING_VERSION=${VERSION} CURRENT_PROJECT_VERSION=${BUILD_NUM})"
rm -rf "${DERIVED}"
mkdir -p "${ROOT}/build/Releases"

xcodebuild -project "MacApp/MisterRogersRenamer.xcodeproj" \
  -scheme MisterRogersRenamer \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED}" \
  "MARKETING_VERSION=${VERSION}" \
  "CURRENT_PROJECT_VERSION=${BUILD_NUM}" \
  build

[[ -d "${APP_SRC}" ]] || { echo "ERROR: missing ${APP_SRC}" >&2; exit 1; }

echo "==> Stage ${OUT_DIR}"
rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
ditto "${APP_SRC}" "${OUT_DIR}/MisterRogersRenamer.app"

echo "==> Zip -> ${OUT_DIR}/${ZIP_NAME}"
rm -f "${OUT_DIR}/${ZIP_NAME}"
ditto -c -k --keepParent "${OUT_DIR}/MisterRogersRenamer.app" "${OUT_DIR}/${ZIP_NAME}"

echo "OK: ${OUT_DIR}/MisterRogersRenamer.app"
echo "OK: ${OUT_DIR}/${ZIP_NAME}"
