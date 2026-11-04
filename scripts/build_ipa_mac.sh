#!/bin/bash
# macOS 上出未签名 IPA：bash scripts/build_ipa_mac.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

xcodebuild \
  -project AKChat.xcodeproj \
  -scheme AKChat \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_ENTITLEMENTS="" \
  build

APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name "*.app" | head -1)
test -n "$APP"
rm -rf Payload AKChat-unsigned.ipa
mkdir -p Payload
cp -R "$APP" Payload/
zip -qry AKChat-unsigned.ipa Payload
shasum -a 256 AKChat-unsigned.ipa
echo "OK: $(pwd)/AKChat-unsigned.ipa"
