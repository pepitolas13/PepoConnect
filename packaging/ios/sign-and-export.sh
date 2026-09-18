#!/bin/bash
# Signs and exports the iOS build when an Apple Developer certificate is provided via secrets.
# Env: IOS_P12_BASE64, IOS_P12_PASSWORD, IOS_PROFILE_BASE64, IOS_TEAM_ID, KC_PW
set -euo pipefail
echo "$IOS_P12_BASE64" | base64 -d > cert.p12
echo "$IOS_PROFILE_BASE64" | base64 -d > profile.mobileprovision
security create-keychain -p "$KC_PW" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "$KC_PW" build.keychain
security set-keychain-settings -lut 21600 build.keychain
security import cert.p12 -k build.keychain -P "$IOS_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PW" build.keychain
UUID=$(security cms -D -i profile.mobileprovision | /usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin)
NAME=$(security cms -D -i profile.mobileprovision | /usr/libexec/PlistBuddy -c 'Print Name' /dev/stdin)
for d in "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; do
  mkdir -p "$d"
  cp profile.mobileprovision "$d/$UUID.mobileprovision"
done
printf 'DEVELOPMENT_TEAM=%s\nCODE_SIGN_STYLE=Manual\nPROVISIONING_PROFILE_SPECIFIER=%s\n' "$IOS_TEAM_ID" "$NAME" >> ios/Flutter/Release.xcconfig
sed -i '' "s/TEAM_ID/$IOS_TEAM_ID/; s/PROFILE_NAME/$NAME/" ios/ExportOptions.plist
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
security delete-keychain build.keychain
